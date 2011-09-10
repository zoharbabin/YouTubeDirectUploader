<?php
//debug  
error_reporting(E_ALL);  

//include Zend Gdata Libs  
require_once("Zend/Gdata/ClientLogin.php");  
require_once("Zend/Gdata/HttpClient.php");  
require_once("Zend/Gdata/YouTube.php");  
require_once("Zend/Gdata/App/MediaFileSource.php");  
require_once("Zend/Gdata/App/HttpException.php");  
require_once('Zend/Uri/Http.php');  

function upload2YouTube($file2up, $email, $pass, $title, $desc, $tags, $cat, $devtags) {
	$authenticationURL= 'https://www.google.com/accounts/ClientLogin';
	$httpClient = Zend_Gdata_ClientLogin::getHttpClient(
			  $username = $email,
			  $password = $pass,
			  $service = 'youtube',
			  $client = null,
			  $source = 'ClippingApp', // a short string identifying your application
			  $loginToken = null,
			  $loginCaptcha = null,
			  $authenticationURL);

	$developerKey = 'AI39si5WWmzMI3O3yPXeLipDKbAzyhGIxLWirhx49EleCJ2dbkDibJArwRTMsjsmYCqcKX8QJMpSRTaErDPvuMieA5qHxTaygQ';
	$applicationId = 'ClippingApp';
	$clientId = 'ClippingApp';

	$yt = new Zend_Gdata_YouTube($httpClient, $applicationId, $clientId, $developerKey);

	// create a new VideoEntry object
	$myVideoEntry = new Zend_Gdata_YouTube_VideoEntry();

	// create a new Zend_Gdata_App_MediaFileSource object
	$filesource = $yt->newMediaFileSource($file2up);
	$filesource->setContentType('video/x-flv');
	// set slug header
	$filesource->setSlug($file2up);

	// add the filesource to the video entry
	$myVideoEntry->setMediaSource($filesource);

	$myVideoEntry->setVideoTitle($title);
	$myVideoEntry->setVideoDescription($desc);
	// The category must be a valid YouTube category!
	$myVideoEntry->setVideoCategory($cat);

	// Set keywords. Please note that this must be a comma-separated string
	// and that individual keywords cannot contain whitespace
	$myVideoEntry->SetVideoTags($tags);

	// set some developer tags -- this is optional
	// (see Searching by Developer Tags for more details)
	$myVideoEntry->setVideoDeveloperTags(explode(",", $devtags));

	// set the video's location -- this is also optional
	$yt->registerPackage('Zend_Gdata_Geo');
	$yt->registerPackage('Zend_Gdata_Geo_Extension');
	$where = $yt->newGeoRssWhere();
	$position = $yt->newGmlPos('37.0 -122.0');
	$where->point = $yt->newGmlPoint($position);
	$myVideoEntry->setWhere($where);

	// upload URI for the currently authenticated user
	$uploadUrl = 'http://uploads.gdata.youtube.com/feeds/api/users/default/uploads';

	// try to upload the video, catching a Zend_Gdata_App_HttpException, 
	// if available, or just a regular Zend_Gdata_App_Exception otherwise
	$err = '';
	try {
	  $newEntry = $yt->insertEntry($myVideoEntry, $uploadUrl, 'Zend_Gdata_YouTube_VideoEntry');
	} catch (Zend_Gdata_App_HttpException $httpException) {
	  $err = $httpException->getRawResponseBody();
	} catch (Zend_Gdata_App_Exception $e) {
	  $err = 'err2'.$e->getMessage();
	}
	if ($err == '')
		return true;
	else
		return false;
}