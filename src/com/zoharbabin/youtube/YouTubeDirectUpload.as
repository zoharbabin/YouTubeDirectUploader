/**
 * In addition to the MIT license, if you make use of this code
 * you should notify the author (Zohar Babin: z.babin@gmail.com).
 * 
 * This program is distributed under the terms of the MIT License as found 
 * in a file called LICENSE. If it is not present, the license
 * is always available at http://www.opensource.org/licenses/mit-license.php.
 *
 * This program is distributed in the hope that it will be useful, but
 * without any waranty; without even the implied warranty of merchantability
 * or fitness for a particular purpose. See the MIT License for full details.
 **/ 
package com.zoharbabin.youtube
{
	import flash.events.DataEvent;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.system.Security;
	import flash.utils.ByteArray;
	
	import org.httpclient.http.multipart.Multipart;
	import org.httpclient.http.multipart.Part;
	
	import ru.inspirit.net.MultipartURLLoader;
	
	/**
	 * Indicates login to YouTube was successful. 
	 **/
	[Event(name="loginSuccess", type="flash.events.Event")]
	/**
	 * Indicates login to YouTube failed. 
	 **/
	[Event(name="loginFailed", type="flash.events.Event")]
	/**
	 * Indicates file was uploaded successfully. 
	 **/
	[Event(name="uploadComplete", type="flash.events.Event")]
	/**
	 * Indicates file failed tp upload.
	 **/
	[Event(name="uploadFailed", type="flash.events.Event")]
	
	/**
	 * A utility class for uploading video files or video ByteArrays to YouTube 
	 * using YouTube direct upload (user email and password instead of OAuth redirects).
	 * 
	 * @author Zohar Babin (z.babin@gmail.com)
	 * @see http://www.zoharbabin.com/youtube-direct-upload-actionscript3
	 **/
	public class YouTubeDirectUpload extends EventDispatcher
	{
		import com.adobe.net.URI;
		import com.adobe.utils.StringUtil;
		
		import mx.controls.Alert;
		import mx.events.FlexEvent;
		
		import org.httpclient.HttpClient;
		import org.httpclient.HttpRequest;
		import org.httpclient.events.HttpDataEvent;
		import org.httpclient.events.HttpResponseEvent;
		import org.httpclient.events.HttpStatusEvent;
		import org.httpclient.http.Get;
		import org.httpclient.http.Post;
		
		/**
		 * The YouTube Developer Key for your application.
		 * @see http://code.google.com/apis/youtube/2.0/developers_guide_protocol_authentication.html#Developer_Key
		 **/
		public var developerKey:String = '';
		/**
		 * The Registered YouTube application name (you should create this in your YouTube partners dashboard).
		 * @see http://code.google.com/apis/youtube/dashboard/
		 **/
		public var appName:String = '';
		/**
		 * The YouTube username of the account to upload the video to. 
		 **/
		protected var youTubeUserEmail:String = '';
		/**
		 * The YouTube password of the account to upload the video to.
		 **/
		protected var youTubePassword:String = '';
		
		/**
		 * This will save the authentication key recieved from YouTube's client login service
		 **/ 
		protected var authKey:String = '';
		
		/**
		 * Indicates whether the file bytes were loaded (in case of filereference browse) 
		 **/ 
		protected var isFileLoaded:Boolean = false;
		/**
		 * Indicates whether upload was completed successfully.
		 **/
		protected var _isUploadCompleted:Boolean = false;
		[Bindable(even="uploadComplete")]
		public function get isUploadCompleted():Boolean {
			return _isUploadCompleted;
		}
		
		/**
		 * ByteArray holding the video to upload.
		 **/
		protected var videoBytes:ByteArray;
		
		/**
		 * Indicates whether uploaded content will be a file selected by the user (true) or a byteArray from the application (false).
		 **/
		protected var uploadFromLocalFilesystem:Boolean = true;
		
		/**
		 * If login failed, this will hold the details.
		 **/
		public var loginErrorEvent:ErrorEvent;
		
		/**
		 * The name of the video as it will be titled in YouTube.
		 **/
		public var ytVideoName:String = 'myvideo';
		
		/**
		 * The description of the video in YouTube.
		 **/
		public var ytVideoDescription:String = 'myvideo';
		
		/**
		 * The YouTube category to categorize the video in (This has to be one of YouTube's pre-defined categories).
		 * @See http://code.google.com/apis/youtube/2.0/reference.html#YouTube_Category_List
		 **/
		public var ytVideoCategory:String = 'People';
		
		/**
		 * The keywords to tag the video on YouTube, this is free-from.
		 **/
		public var ytKeywords:String = 'myvideo';
		
		/**
		 * This is a special invisible tag for application developers to search their application
		 * uploaded videos in YouTube, this can only be set during upload time.
		 * @see http://code.google.com/apis/youtube/2.0/developers_guide_protocol.html#Assigning_Developer_Tags
		 **/
		public var developerTag:String = 'zoharbabin.com';
		
		
		/**
		 * The url to YouTube's direct client login service.
		 **/
		private var clientLoginUrl:String = 'https://www.google.com/accounts/ClientLogin';
		/**
		 * The url to YouTube's direct upload token service.
		 **/
		private var uploadMethodUrl:String = 'http://gdata.youtube.com/action/GetUploadToken';
		
		/**
		 * A gateway Url to avoid Google's poor crossdomain.xml file.
		 **/
		[Bindable]
		public var gatewayUrl:String = 'ytapi/ytgateway.php';
		
		/**
		 * A gateway Url for the upload service to avoid Google's poor crossdomain.xml file.
		 **/
		[Bindable]
		public var gatewayUrlUpload:String = 'ytapi/savefileanduploadtoyt.php';
		/**
		 * Will be used to retrive the local file to upload and to upload
		 **/
		private var fileReference:FileReference;
		
		/**
		 * YouTube login call, listen to loginSuccess and loginFailed to respond.
		 **/
		public function youTubeLogin (yt_useremail:String, yt_password:String):void 
		{
			Security.loadPolicyFile('http://gdata.youtube.com/crossdomain.xml');
			Security.loadPolicyFile('https://accounts.googleapis.com/crossdomain.xml');
			youTubeUserEmail = yt_useremail;
			youTubePassword = yt_password;
			var body:String = 'Email='+youTubeUserEmail+'&Passwd='+youTubePassword+'&service=youtube&source='+appName;
			var urlRequest:URLRequest = new URLRequest(clientLoginUrl);
			urlRequest.method = URLRequestMethod.POST;
			urlRequest.requestHeaders.push(new URLRequestHeader('Content-Type', 'application/x-www-form-urlencoded'));
			urlRequest.requestHeaders.push(new URLRequestHeader('X-HTTP-Method-Override', 'POST'));
			urlRequest.data = body;
			var urlLoader:URLLoader = new URLLoader();
			urlLoader.addEventListener(Event.COMPLETE, authCompleteHandler);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, authFailedHandler);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, authFailedHandler);
			urlLoader.load(urlRequest);
		}

		/**
		 * YouTube login call through a gateway (to avoid security issues), listen to loginSuccess and loginFailed to respond.
		 **/
		public function youTubeLoginGateway (yt_useremail:String, yt_password:String):void 
		{
			Security.loadPolicyFile('http://gdata.youtube.com/crossdomain.xml');
			Security.loadPolicyFile('https://accounts.googleapis.com/crossdomain.xml');
			youTubeUserEmail = yt_useremail;
			youTubePassword = yt_password;
			var body:String = 'yt_email='+youTubeUserEmail+'&yt_pass='+youTubePassword+'&yt_service=youtube&yt_appname='+appName;
			var loginurl:String = gatewayUrl + '?' + body;
			var urlRequest:URLRequest = new URLRequest(loginurl);
			urlRequest.method = URLRequestMethod.GET;
			var urlLoader:URLLoader = new URLLoader();
			urlLoader.addEventListener(Event.COMPLETE, authCompleteHandler);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, authFailedHandler);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, authFailedHandler);
			urlLoader.load(urlRequest);
		}
		
		/**
		 * login to YouTube was successful.
		 **/
		private function authCompleteHandler(event:Event):void {
			var urlLoader:URLLoader = URLLoader(event.target);
			var result:String = urlLoader.data;
			authKey = result.substr(result.indexOf('Auth=')+5);
			authKey = StringUtil.trim(authKey); //'end of line' symbol at the end of the token messes up the API and returns 411
			authKey = authKey.substring("auth string is:".length,authKey.length);
			if (authKey.length > 6) {
				trace ('Got auth: '+authKey);
				dispatchEvent(new Event("loginSuccess"));
			} else {
				dispatchEvent(new Event("loginFailed"));
			}
		}
		
		/**
		 *  authentication with YouTube failed.
		 **/
		private function authFailedHandler(event:ErrorEvent):void {
			dispatchEvent(new Event("loginFailed"));
			loginErrorEvent = event;
		}
		
		/**
		 * Open a browse window to upload file from file system.
		 **/
		public function uploadBrowse():void {
			uploadFromLocalFilesystem = true;
			fileReference = new FileReference();
			fileReference.addEventListener(Event.SELECT, fileSelectHandler, false, 0, true);
			fileReference.addEventListener(ProgressEvent.PROGRESS, progressHandler, false, 0, true);
			fileReference.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler, false, 0, true);
			fileReference.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler, false, 0, true);
			fileReference.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, uploadComplete, false, 0, true);
			fileReference.addEventListener(Event.COMPLETE, uploadDataComplete, false, 0, true);
			isFileLoaded = false;
			_isUploadCompleted = false;
			//http://www.google.com/support/youtube/bin/answer.py?answer=55744
			var videoFilter:FileFilter = new FileFilter("Video", "*.flv; *.wmv; *.mpeg; *.mpg; *.f4v; *.vp8; *.webm; *.3gp; *.mp4; *.mov; *.avi; *.mpegs; *.mpg; *.3gpp;");
			fileReference.browse([videoFilter]);
		}
		
		/**
		 * file was selected by the user, now load the bytearray of the file
		 **/
		private function fileSelectHandler(event:Event):void {
			fileReference.load();
		}
		
		/**
		 * If user browsed for file - this will be called twice, once for loading local file and then after upload success,
		 * If we're upload from byteArray - this will be called once, after upload success.
		 **/
		private function uploadDataComplete (event:Event):void {
			if (!isFileLoaded) {
				videoBytes = fileReference.data;
				isFileLoaded = true;
				createAtomFeed();
			}
		}
		
		/**
		 * Upload a ByteArray (without asking the user to browse & select local file).
		 **/
		public function uploadByteArray (video_bytes:ByteArray):void {
			uploadFromLocalFilesystem = false;
			_isUploadCompleted = false;
			isFileLoaded = true;
			videoBytes = video_bytes;
			//createAtomFeed();
			gatewayUpload ();
		}
		
		/**
		 * It might be required to use a gateway to overcome Google's crossdomain issues,
		 * use this function if you experience issues with security and setup a gateway on your server.
		 * @see savefileanduploadtoyt.php
		 * @see ytupload.php
		 **/
		public function gatewayUpload ():void {
			//savefileanduploadtoyt.php
			var req:URLRequest;
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			req = new URLRequest(gatewayUrlUpload + "?email="+youTubeUserEmail + 
													"&pass="+youTubePassword +
													"&title="+ytVideoName +
													"&desc="+ytVideoDescription +
													"&tags="+ytKeywords + 
													"&cat="+ytVideoCategory +
													"&devtags="+developerTag );
			req.method = URLRequestMethod.POST;
			req.contentType = 'application/octet-stream';
			req.data = videoBytes;
			loader.addEventListener(Event.COMPLETE, gatewayComplete);
			loader.addEventListener(IOErrorEvent.IO_ERROR, gatewayIOError);
			loader.load(req);
		}
		
		/**
		 * Success handler for the gateway upload.
		 **/
		private function gatewayComplete(event:Event):void {
			var msg:String = event.target.data;
			trace ("gatewayComplete: "+msg);
			_isUploadCompleted = true;
			dispatchEvent(new Event("uploadComplete"));
		}
		
		/**
		 * Error handler for the gateway upload.
		 **/
		private function gatewayIOError(event:IOErrorEvent):void {
			trace('An error occurred (gatewayIOError): ' + event.text);
			dispatchEvent(new Event("uploadFailed"));
		}
		
		/**
		 * Create the file Atom feed to get upload token from YouTube.
		 **/
		private function createAtomFeed():void {
			// Obviously, this shouldn't be hardcoded in a real application!
			var atom:String = '<?xml version="1.0"?>';
			atom += '<entry xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/" xmlns:yt="http://gdata.youtube.com/schemas/2007">';
			atom += '<media:group><media:title type="plain">'+ytVideoName+'</media:title>';
			atom += '<media:description type="plain">'+ytVideoDescription+'</media:description>';
			atom += '<media:category scheme="http://gdata.youtube.com/schemas/2007/categories.cat">'+ytVideoCategory+'</media:category>';
			// Developer tags are not user-visible and provide an easy way for you to find videos uploaded with your developer key.
			atom += '<media:category scheme="http://gdata.youtube.com/schemas/2007/developertags.cat">'+developerTag+'</media:category>';
			atom += '<media:keywords>'+ytKeywords+'</media:keywords></media:group></entry>';
			
			var client:HttpClient = new HttpClient();
			var uri:URI = new URI(uploadMethodUrl);
			var request:HttpRequest = new Post();
			request.addHeader('GData-Version', '2');
			request.addHeader('X-GData-Client', appName);
			request.addHeader('Content-Type', 'application/atom+xml; charset=UTF-8');
			request.addHeader('Authorization', 'GoogleLogin auth='+authKey);
			request.addHeader('X-GData-Key', 'key='+developerKey);
			var reqdata:ByteArray = new ByteArray();
			reqdata.writeUTFBytes(atom);
			reqdata.position = 0;
			request.addHeader('Content-Length', reqdata.length.toString());
			request.body = reqdata;
			
			client.listener.onStatus = function(event:HttpStatusEvent):void {
				// Notified of response (with headers but not content)
				trace(event.code);
			};
			
			client.listener.onData = function(event:HttpDataEvent):void {
				// For string data
				var stringData:String = event.readUTFBytes();
				trace(stringData);
				uploadTokenLoadCompleteHandler(stringData);
			};
			
			client.listener.onComplete = function(event:HttpResponseEvent):void {
				// Notified when complete (after status and data)
				trace(event.response.code);
			};
			
			client.listener.onError = function(event:ErrorEvent):void {
				var errorMessage:String = event.text;
				Alert.show(errorMessage);
				trace(errorMessage);
			};      
			
			client.request(uri, request);
		}
		
		/**
		 * After YouTube respond with valid upload token, we parse the response XML and upload the file.
		 **/
		private function uploadTokenLoadCompleteHandler(data:String):void {
			var uploadUrl:String;
			var uploadToken:String;
			
			// Regexes are the lazy-man's XML parsing.
			var urlRegex:RegExp = /<url>(.+)<\/url>/;
			var result:Array = urlRegex.exec(data);
			if (result == null) {
				trace("Couldn't determine upload URL.");
			} else {
				var hostUrl:String = 'http%3A%2F%2Fwww.zoharbabin.com';
				uploadUrl = result[1] + '?nexturl=' + hostUrl;
			}
			
			var tokenRegex:RegExp = /<token>(.+)<\/token>/;
			result = tokenRegex.exec(data);
			if (result == null) {
				trace("Couldn't determine upload token.");
			} else {
				uploadToken = result[1];
			}
			
			if (uploadUrl != null && uploadToken != null) {
				trace (uploadUrl);
				trace (uploadToken);
				uploadFile(uploadUrl, uploadToken);
			}
		}
		
		private function uploadFile(uploadUrl:String, uploadToken:String):void {
			if (uploadFromLocalFilesystem) {
				//upload a file from local filesystem selected by the user
				var parameters:URLVariables = new URLVariables();
				parameters['token'] = uploadToken;
				var urlRequest:URLRequest = new URLRequest(uploadUrl);
				urlRequest.method = URLRequestMethod.POST;
				urlRequest.requestHeaders.push(new URLRequestHeader('GData-Version', '2'));
				urlRequest.requestHeaders.push(new URLRequestHeader('X-GData-Client', appName));
				urlRequest.requestHeaders.push(new URLRequestHeader('Content-Type', 'application/atom+xml; charset=UTF-8'));
				urlRequest.requestHeaders.push(new URLRequestHeader('Authorization', 'GoogleLogin auth='+authKey));
				urlRequest.requestHeaders.push(new URLRequestHeader('X-GData-Key', 'key='+developerKey));
				urlRequest.data = parameters;
				fileReference.upload(urlRequest, 'file');
			} else {
				var ml:MultipartURLLoader = new MultipartURLLoader();
				ml.addEventListener(Event.COMPLETE, onReady);
				ml.addEventListener(ProgressEvent.PROGRESS, progressHandler);
				ml.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				ml.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
				ml.requestHeaders = [
									new URLRequestHeader('GData-Version', '2'),
									new URLRequestHeader('X-GData-Client', appName),
									new URLRequestHeader('Authorization', 'GoogleLogin auth='+authKey),
									new URLRequestHeader('X-GData-Key', 'key='+developerKey)
										];
				ml.addFile(videoBytes, '', 'file', 'application/atom+xml; charset=UTF-8');
				ml.addVariable('token', uploadToken);
				ml.load(uploadUrl);
			}
		}
		
		private function onReady(e:Event):void
		{
			trace ("Upload to YouTube Successfully Done (MultipartUpload)");
			_isUploadCompleted = true;
			dispatchEvent(new Event("uploadComplete"));
		}
		
		/**
		 * When using filereference upload:
		 * YouTube will communicate success through passing 302 status (redirect) after successful upload.
		 **/
		private function httpStatusHandler(event:HTTPStatusEvent):void {
			// Browser-based uploads end with a HTTP 302 redirect to the 'nexturl' page.
			// However, Flash doesn't properly handle this redirect. So we just use the presence of the 302
			// redirect to assume success. It's not ideal. More info on browser-based uploads can be found at
			// http://code.google.com/apis/youtube/2.0/developers_guide_protocol_browser_based_uploading.html
			if (event.status == 302) {
				trace ("Upload to YouTube Successfully Done");
				_isUploadCompleted = true;
				dispatchEvent(new Event("uploadComplete"));
			}
		}
		
		private function uploadComplete (event:DataEvent):void {
			trace('upload completed successfully');
			trace(event.data);
		}
		
		private function progressHandler(event:ProgressEvent):void {
			var percent:Number = Math.round(100 * event.bytesLoaded / event.bytesTotal);
			trace('Uploading file... ' + percent + '% complete.');
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void {
			// uploadComplete is set in the httpStatusHandler when the HTTP 302 is returned by the YouTube API.
			if (!_isUploadCompleted) {
				trace('An error occurred: ' + event.text);
				dispatchEvent(new Event("uploadFailed"));
			}
		}
	}
}