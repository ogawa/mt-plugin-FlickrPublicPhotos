# A plugin for adding "FlickrPublicPhotos" container and related tags
#
# Release 0.11 (Mar 6, 2005)
#
# This software is provided as-is. You may use it for commercial or 
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2005 Hirotaka Ogawa

package MT::Plugin::FlickrPublicPhotos;
use strict;

my $plugin;
eval {
    require MT::Plugin;
    $plugin = new MT::Plugin();
    $plugin->name("FlickrPublicPhotos Plugin");
    $plugin->description("Add FlickrPublicPhotos container and related tags. Version 0.11");
    $plugin->doc_link("http://as-is.net/hacks/2005/05/flickrpublicphotos_plugin.html");
    MT->add_plugin($plugin);
};

use MT::Template::Context;

MT::Template::Context->add_container_tag('FlickrPublicPhotos' => \&photos);
MT::Template::Context->add_tag('FlickrPublicPhotoTitle' => \&photo_title);
MT::Template::Context->add_tag('FlickrPublicPhotoURL' => \&photo_url);
MT::Template::Context->add_tag('FlickrPublicPhotoImgURL' => \&photo_img_url);

sub photos {
    my ($ctx, $args) = @_;
    my $user = $args->{user} or $ctx->error("'user' must be specified");

    my $flickr = new MT::Plugin::FlickrPublicPhotos::API();
    my @photos = $flickr->photos($user);

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
    $_[0]->stash('flickr_public_photo')->img_url($_[1]->{size} || 't');
}

package MT::Plugin::FlickrPublicPhotos::Photo;

sub new {
    my ($class, $params) = @_;
    $params ||= {};
    bless $params, $class;
}

sub title {
    my $this = shift;
    $this->{title} || '';
}

sub url {
    my $this = shift;
    my $url = 'http://www.flickr.com/photos/' . $this->{nsid} . '/' . $this->{id} . '/';
    $url;
}

sub img_url {
    my $this = shift;
    my ($size) = @_;
    $size ||= 't';
    my $url = 'http://photos' . $this->{server} . '.flickr.com/' . $this->{id} . '_' . $this->{secret} . '_' . $size . '.jpg';
    $url;
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
    my $rsp = $this->execute_method('flickr.people.getPublicPhotos',
				    { user_id => $nsid });
    die "Flickr request failed: " . $rsp->{error_message} . "\n"
	unless $rsp->{success} == 1;

    my $xpath = new XML::Parser::Lite::Tree::XPath();
    $xpath->set_tree($rsp->{tree});
    my @photoNodes = $xpath->select_nodes('/photos/photo');
    for my $node (@photoNodes) {
	my $photo = new MT::Plugin::FlickrPublicPhotos::Photo();
	$photo->{id} = $node->{attributes}{id};
	$photo->{nsid} = $nsid;
	$photo->{secret} = $node->{attributes}{secret};
	$photo->{server} = $node->{attributes}{server};
	$photo->{title} = $node->{attributes}{title};
	push @photos, $photo;
    }
    return @photos;
}

1;
