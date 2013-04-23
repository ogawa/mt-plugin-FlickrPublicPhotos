# FlickrPublicPhotos Plugin

A Movable Type plugin for listing [Flickr](http://www.flickr.com/)'s Public Photos.  This plugin employs [Flickr API](http://www.flickr.com/services/api/) and [Flickr::API](http://search.cpan.org/~iamcal/Flickr-API-0.03/) module.

## Changes

 * 0.10(2005.05.05):
   * First Release.
 * 0.11(2005.05.06):
   * Code cleanup.
 * 0.12(2005.05.07):
   * Support 100+ public photos.
   * Add more variable tags for displaying the information of the photo.
 * 0.13(2005.05.08):
   * First Release in English.
 * 0.20(2005.05.27):
   * Speedup, and countermeasure for Flickr service down.
 * 0.21(2005.06.08):
   * A bug fix release

## Overview

FlickrPublicPhotos Plugin allows you to list public photos of an Flickr account owner, which can be specified by his/her username or mail address, or NSID.  The plugin can show not only full-set of his/her public photos, but also recent N photos or random N photos.

## Requirements

This plugin is supported on Movable Type 3.0 or later.

The following Perl Modules provided by Cal Henderson are required:

 * [http://search.cpan.org/~iamcal/Flickr-API-0.03/]()
 * [http://search.cpan.org/~iamcal/XML-Parser-Lite-Tree-0.03/]()
 * [http://search.cpan.org/~iamcal/XML-Parser-Lite-Tree-XPath-0.02/]()

## Installation

To install this plugin, upload org copy 'FlickrPublicPhotos.pl' into your Movable Type's plugin directory.

After proper installation, you will see a new "FlickrPublicPhotos Plugin" listed on the Main Menu of your Movable Type.

## Tags

### MTFlickrPublicPhotos container tag

MTFlickrPublicPhotos is the container tag, which requires, or can be specified with, the following three options:

 * user="username|user@mail.address|123456@N00" (required): Choose the owner of public photos you want to show.  The owner can be specified as his/her Flickr's username or e-mail address, or NSID.
 * lastn="N" (optional): Show recent N public photos.
 * random="N" (optional): Show random N public photos.
 * refresh="R" (optional): This option is to cache Public Photos information obtained via Flickr API for R seconds. Default R is 3600 seconds(=1 hour).

When omitting both "lastn" and "random" options, all public photos are listed.  And if being specified both options, "lastn" setting is ignored.

The following six tags are available inside of the MTFlickrPublicPhotos container tag:

### MTFlickrPublicPhotoTitle tag

Variable tag for showing the title of the photo.

### MTFlickrPublicPhotoURL tag

Variable tag for showing the URL of the Flickr's photo page.

### MTFlickrPublicPhotoImgURL tag

Varibale tag for showing the URL of the thumbnail image of the photo.  This tag can be specified with the following option:

 * size="sq|t|s|m|l|o": The option is to choose the size of the thumbnail. Each value means "Square(75x75)", "Thumbnail(100x75 or75x100)", "Small", "Medium", "Large", "Original".  The default setting of this options is "t" (Thumbnail size).
 * cache="relative-path": This option is to download Photo images to local and return local URLs. This option is OFF by default. ''relative-path'' should specify the directory for images, which is relative to "Local Site Path".
 * cache_refresh="R": This option is to specify the lifetime of downloaded images. Rebuilding after R seconds, FlickrPublicPhotos plugin tries to download them again. The default R is 86400 seconds(=1 day).

### MTFlickrPublicPhotoUploadDate tag

Variable tag for showing the "uploaded date" of the photo.  This tag can be used with various options for displaying "date", as well as MTDate or MTEntryDate.

### MTFlickrPublicPhotoTakenDate tag

Variable tag for showing the "taken date" of the photo.  This tag can be used with various options for displaying "date", as well as MTDate or MTEntryDate.

### MTFlickrPublicPhotoOwnerName tag

Variable tag for showing the "owner name" of the photo.

## Example

To show the latest 5 public photos of the user named "Hirotaka Ogawa", with Square size (75x75), add the following into your template:

    <p class="flickr-photo">
    <MTFlickrPublicPhotos user="Hirotaka Ogawa" lastn="5">
    <a href="<$MTFlickrPublicPhotoURL$>" title="<$MTFlickrPublicPhotoTitle encode_html="1"$>">
    <img src="<$MTFlickrPublicPhotoImgURL size="s"$>" />
    </a>
    </MTFlickrPublicPhotos>
    </p>

The output will be shown as below:

    <p class="flickr-photo">
      <a href="http://www.flickr.com/photos/25545765@N00/11771398/" title="P1000775">
        <img src="http://photos9.flickr.com/11771398_05b7253738_s.jpg" />
      </a>
      <a href="http://www.flickr.com/photos/25545765@N00/11771393/" title="P1000774">
        <img src="http://photos7.flickr.com/11771393_60f21b3ffb_s.jpg" />
      </a>
      <a href="http://www.flickr.com/photos/25545765@N00/11771382/" title="P1000773">
        <img src="http://photos7.flickr.com/11771382_2a90b25b13_s.jpg" />
      </a>
      <a href="http://www.flickr.com/photos/25545765@N00/11771366/" title="P1000772">
        <img src="http://photos7.flickr.com/11771366_6ad79ba64d_s.jpg" />
      </a>
      <a href="http://www.flickr.com/photos/25545765@N00/11771348/" title="P1000771">
        <img src="http://photos8.flickr.com/11771348_3106fef18a_s.jpg" />
      </a>
    </p>

The above will look like in your browser:

![](images/FlickrPublicPhotos-Example.jpg)

## See Also

## License

This code is released under the Artistic License. The terms of the Artistic License are described at [http://www.perl.com/language/misc/Artistic.html]().

## Author & Copyright

Copyright 2005, Hirotaka Ogawa (hirotaka.ogawa at gmail.com)
