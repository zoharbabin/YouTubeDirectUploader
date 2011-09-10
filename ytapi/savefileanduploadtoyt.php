<?php
require 'ytupload.php';

$im = $GLOBALS["HTTP_RAW_POST_DATA"];
$email = $_GET["email"];
$pass = $_GET["pass"];
$title = $_GET["title"];
$desc = $_GET["desc"];
$tags = $_GET["tags"];
$cat = $_GET["cat"];
$devtags = $_GET["devtags"];
$filename = '';
for ($i=0; $i < 7; ++$i){
	$filename .= chr(rand(97,122));
}
$filename = "tempfile".time()."x.flv";
$fp = fopen($filename, 'w'); 
fwrite($fp, $im);
fclose($fp);
$ret = upload2YouTube ($filename, $email, $pass, $title, $desc, $tags, $cat, $devtags);
unlink($filename);
print $ret;