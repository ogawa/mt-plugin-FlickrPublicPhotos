# A plugin for adding "FlickrPublicPhotos" container and related tags
#
# $Id$
#
# This software is provided as-is. You may use it for commercial or 
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2005 Hirotaka Ogawa

package MT::Plugin::FlickrPublicPhotos;
use strict;
use vars qw($VERSION);

$VERSION = '0.22';

my $plugin;
eval {
    require MT::Plugin;
    $plugin = new MT::Plugin({
	name => 'FlickrPublicPhotos',
	description => 'Add FlickrPublicPhotos container and related tags.',
	doc_link => 'http://as-is.net/hacks/2005/05/flickrpublicphotos_plugin.html',
	author_name => 'Hirotaka Ogawa',
	author_link => 'http://profile.typekey.com/ogawa/',
	version => $VERSION
	});
    MT->add_plugin($plugin);
};

use MT::Template::Context;
use MT::Util qw(offset_time_list);

MT::Template::Context->add_container_tag('FlickrPublicPhotos' => \&photos);
MT::Template::Context->add_tag('FlickrPublicPhotoTitle' => \&photo_title);
MT::Template::Context->add_tag('FlickrPublicPhotoURL' => \&photo_url);
MT::Template::Context->add_tag('FlickrPublicPhotoImgURL' => \&photo_img_url);
MT::Template::Context->add_tag('FlickrPublicPhotoUploadDate' => \&date_upload);
MT::Template::Context->add_tag('FlickrPublicPhotoTakenDate' => \&date_taken);
MT::Template::Context->add_tag('FlickrPublicPhotoOwnerName' => \&owner_name);

# Load photos via FlickrAPI
sub load_photos_fapi {
    my ($user) = @_;
    my $flickr = new MT::Plugin::FlickrPublicPhotos::API();
    return $flickr->photos($user);
}

# Load and cache photos
sub load_photos {
    my ($user, $refresh) = @_;
    require MT::PluginData;
    my $pd = MT::PluginData->load({ plugin => $plugin->name,
				    key => $user });
    if (!$pd) {
	$pd = new MT::PluginData();
	$pd->plugin($plugin->name);
	$pd->key($user);
    }
    my $data = $pd->data() || {};
    my $now = time;
    if (!defined($data->{last_updated}) || !defined($data->{photos}) ||
	($now - $data->{last_updated} >= $refresh)) {
	my @photos = eval { load_photos_fapi($user); };
	# if FlickrAPI call fails, reuse cache
	if (!$@ || !defined($data->{photos})) {
	    $data->{photos} = \@photos;
	    $data->{last_updated} = $now;
	}
	$pd->data($data);
	$pd->save or die $pd->errstr;
    }
    return @{$data->{photos}};
}

sub photos {
    my ($ctx, $args) = @_;
    my $user = $args->{user} or $ctx->error("'user' must be specified");
    my $refresh = $args->{refresh} || 3600; # default: 1h
    my @photos = eval { load_photos($user, $refresh); };
    # if MT::PluginData is unavailable
    @photos = eval { load_photos_fapi($user); } if $@;

    my $lastn = $args->{lastn} || 0;
    my $random = $args->{random} || 0;
    if ($random) {
	use List::Util qw(shuffle);
	@photos = shuffle(@photos);
	$lastn = $random;
    }
    
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $res = '';
    my $i = 0;
    for my $photo (@photos) {
	last if $lastn && $i >= $lastn;
	$ctx->stash('flickr_public_photo', $photo);
	defined(my $out = $builder->build($ctx, $tokens))
	    or return $ctx->error($ctx->errstr);
	$res .= $out;
	$i++;
    }
    $res;
}

sub photo_title {
    $_[0]->stash('flickr_public_photo')->title;
}

sub photo_url {
    $_[0]->stash('flickr_public_photo')->url;
}

sub photo_img_url {
    my ($ctx, $args) = @_;
    my $url = $ctx->stash('flickr_public_photo')->img_url($args->{size} || 't');
    my $cache = $args->{cache} or return $url;
    $cache .= '/' unless $cache =~ m!/$!;
    my $refresh = $args->{cache_refresh} || 86400; # default: 24h

    my ($fname) = $url =~ m!^https?://.+/(.*)$!;

    my $site_url = $ctx->stash('blog')->site_url;
    $site_url .= '/' unless $site_url =~ m!/$!;
    $site_url .= $cache . $fname;

    my $path = $ctx->stash('blog')->site_path;
    $path .= '/' unless $path =~ m!/$!;
    $path .= $cache;
    my $fmgr = $ctx->stash('blog')->file_mgr;
    unless ($fmgr->exists($path)) {
	# mkpath, and if can't return original url
	$fmgr->mkpath($path) or return $url;
    }
    $path .= $fname;

    my $mtime = 0;
    my $now = time;
    if ($fmgr->exists($path)) {
	$mtime = (stat($path))[9];
	return $site_url if ($refresh && ($now - $mtime < $refresh));
    }

    require LWP::UserAgent;
    require HTTP::Request;
    require HTTP::Response;
    require HTTP::Date;
    my $req = HTTP::Request->new(GET => $url);
    my $ua = LWP::UserAgent->new;
    $req->header('If-Modified-Since', HTTP::Date::time2str($mtime)) if $mtime;
    my $rsp = $ua->request($req);
    if ($rsp->is_success && $rsp->content) {
	# put_data, and if can't return original url
	$fmgr->put_data($rsp->content, $path) or return $url;
	$url = $site_url;
    } elsif ($rsp->code == 304) { # not modified
	utime $now, $now, $path; # touch it
	$url = $site_url;
    }
    $url;
}

sub date_upload {
    my $args = $_[1];
    my $t = $_[0]->stash('flickr_public_photo')->date_upload; # epoch format
    my @ts = $args->{utc} ?
	gmtime $t : offset_time_list($t, $_[0]->stash('blog_id'));
    $args->{ts} = sprintf "%04d%02d%02d%02d%02d%02d", $ts[5]+1900, $ts[4]+1, @ts[3,2,1,0];
    MT::Template::Context::_hdlr_date($_[0], $args);
}

sub date_taken {
    my $args = $_[1];
    $args->{ts} = $_[0]->stash('flickr_public_photo')->date_taken;
    MT::Template::Context::_hdlr_date($_[0], $args);
}

sub owner_name {
    $_[0]->stash('flickr_public_photo')->owner_name;
}

package MT::Plugin::FlickrPublicPhotos::Photo;

sub new {
    my ($class, $params) = @_;
    $params ||= {};
    bless $params, $class;
}

sub title {
    $_[0]->{title} || '';
}

sub url {
    my $this = shift;
    my $url = 'http://www.flickr.com/photos/' . $this->{nsid} . '/' . $this->{id} . '/';
    $url;
}

{
my %sizes = (
    sq => '_s',
    t => '_t',
    s => '_m',
    m => '',
    l => '_b',
    o => '_o',
    square => '_s',
    thumbnail => '_t',
    small => '_m',
    medium => '',
    large => '_b',
    original => '_o',
);
sub img_url {
    my $this = shift;
    my ($size) = @_;
    $size = $sizes{(lc $size) || 't'};
    my $url = 'http://static.flickr.com/' . $this->{server} . '/' . $this->{id} . '_' . $this->{secret} . $size . '.jpg';
    $url;
}
}

# INPUT/OUTPUT: UNIX epoch format (should be converted to "YYYYMMDDHHMMSS")
sub date_upload {
    $_[0]->{dateupload} || '';
}

# INPUT: MySQL datetime in owner's localtime
# OUTPUT: "YYYYMMDDHHMMSS" format
sub date_taken {
    my $date = $_[0]->{datetaken};
    if ($date =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/) {
	sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $6;
    } elsif ($date =~ /(\d\d\d\d)-(\d\d)/) {
	sprintf "%04d%02d01000000", $1, $2;
    } elsif ($date =~ /(\d\d\d\d)/) {
	sprintf "%04d0101000000", $1;
    }
}

sub owner_name {
    $_[0]->{ownername} || '';
}

package MT::Plugin::FlickrPublicPhotos::API;
use base 'Flickr::API';
use XML::Parser::Lite::Tree::XPath;
use constant API_KEY => '9765114fb37045ea8d2ca9d813e24b63';

sub new {
    my ($class, $params) = @_;
    my $key = $params->{key} || API_KEY;
    bless $class->SUPER::new({ key => $key }), $class;
}

sub resolve_nsid {
    my $this = shift;
    my ($uname) = @_;
    return $uname if $uname =~ /^\d+\@N00$/;

    my $rsp = ($uname =~ /^[^@]+@[^.]+\..+/) ?
	$this->execute_method('flickr.people.findByEmail',
			      { find_email => $uname }) :
	$this->execute_method('flickr.people.findByUsername',
			      { username => $uname });
    die "Flickr request failed: " . $rsp->{error_message} . "\n"
	unless $rsp->{success} == 1;

    my $xpath = new XML::Parser::Lite::Tree::XPath();
    $xpath->set_tree($rsp->{tree});
    return ($xpath->select_nodes('//user'))[0]->{attributes}{id};
}

sub photos {
    my $this = shift;
    my ($uname) = @_;
    my @photos = ();
    my $nsid = $this->resolve_nsid($uname);
    my ($page, $pages) = (1, 0);
    my $xpath = new XML::Parser::Lite::Tree::XPath();
    do {
	my $rsp = $this->execute_method('flickr.people.getPublicPhotos',
					{ user_id => $nsid,
					  page => $page,
					  extras => 'license,date_upload,date_taken,owner_name,icon_server'
					  });
	die "Flickr request failed: " . $rsp->{error_message} . "\n"
	    unless $rsp->{success} == 1;
	$xpath->set_tree($rsp->{tree});
	$pages ||= ($xpath->select_nodes('//photos'))[0]->{attributes}{pages};
	my @photoNodes = $xpath->select_nodes('/photos/photo');
	for my $node (@photoNodes) {
	    my $photo = new MT::Plugin::FlickrPublicPhotos::Photo();
	    $photo->{id} = $node->{attributes}{id};
	    $photo->{nsid} = $nsid;
	    $photo->{secret} = $node->{attributes}{secret};
	    $photo->{server} = $node->{attributes}{server};
	    $photo->{title} = $node->{attributes}{title};
	    $photo->{license} = $node->{attributes}{license};
	    $photo->{dateupload} = $node->{attributes}{dateupload};
	    $photo->{datetaken} = $node->{attributes}{datetaken};
	    $photo->{datetakengranularity} = $node->{attributes}{datetakengranularity};
	    $photo->{ownername} = $node->{attributes}{ownername};
	    $photo->{iconserver} = $node->{attributes}{iconserver};
	    push @photos, $photo;
	}
    } while ($page++ < $pages);
    return @photos;
}

1;
