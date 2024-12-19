<?php

//session_start();

require(__DIR__ . '/../../Vendor/nusoap/lib/nusoap.php');

function doLogin($user, $password)
{
    try {        
        require_once 'soap_setup.php';
        soapSetup();
        $service = new \Application\Services\LoginService();
        $ip = $_SERVER['REMOTE_ADDR'];
        //$encrypter = new \Services\EncryptPasswordService();
        //$password = $encrypter->encode($password);
        return $service->login($user, $password, $ip);
    } catch (Exception $ex) {
        error_log($ex);
        return "<error>" . $ex->getMessage() . "<error>";
    }
}


$server = new soap_server();
$server->configureWSDL('login', 'urn:sead');
$server->register('doLogin',
    array('user' => 'xsd:string', 'password' => 'xsd:string'),
    array('return' => 'xsd:string'),
    'urn:sead',
    'urn:sead#doLogin',
    'rpc',
    'literal',
    'Login to system'
);

$HTTP_RAW_POST_DATA = isset($HTTP_RAW_POST_DATA) ? $HTTP_RAW_POST_DATA : "";
ob_clean();
$server->service($HTTP_RAW_POST_DATA);
