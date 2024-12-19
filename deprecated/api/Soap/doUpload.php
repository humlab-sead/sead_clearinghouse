<?php

require(__DIR__ . '/../../Vendor/nusoap/lib/nusoap.php');    

function doUpload($user, $password, $file, $datatypes){
    try {
        require 'soap_setup.php';
        soapSetup();
        $service = new \Application\Services\UploadService();
        //$encrypter = new \Services\EncryptPasswordService();
        //$password = $encrypter->encode($password);
        return $service->upload($user, $password, $file, $datatypes);
    } catch (Exception $ex) {
        return "<error>" . $ex->getMessage() . "</error>";
    }    
}
    
$server = new soap_server();
$server->configureWSDL('upload','urn:sead');
$server->register('doUpload',
    array('user' => 'xsd:string', 'password' => 'xsd:string', 'file' => 'xsd:string', 'datatypes' => 'xsd:string'),
    array('return' => 'xsd:string'),
    'urn:sead',
    'urn:sead#doUpload',
    'rpc',
    'literal',
    'Upload a file attached to the caller.'
);

$HTTP_RAW_POST_DATA = isset($HTTP_RAW_POST_DATA) ? $HTTP_RAW_POST_DATA : "";
ob_clean();
$server->service($HTTP_RAW_POST_DATA);