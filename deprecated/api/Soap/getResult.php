<?php

/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

require(__DIR__ . '/../../Vendor/nusoap/lib/nusoap.php');    

function getResult($user, $password, $submissionId){
    require_once 'soap_setup.php';
    soapSetup();
    try {
        $submissionService = new \Application\Services\SubmissionResultService();
        //$encoder = new \Services\EncryptPasswordService();
        //$password = $encoder->encode($password);
        $result = $submissionService->getSubmissionResult($user, $password, $submissionId);
        return $result;
    } catch (Exception $ex) {
        return "<error>" . $ex->getMessage() . "</error>";
    }
}

$server = new soap_server();
$server->configureWSDL('result','urn:sead');
$server->register('getResult',
    array('user' => 'xsd:string', 'password' => 'xsd:string', 'submissionId' => 'xsd:string'),
    array('return' => 'xsd:string'),
    'urn:sead',
    'urn:sead#getResult',
    'rpc',
    'literal',
    'Get the result for the submission, if any. Will return an xml containing a list of associations between localId and public db id, a list of rejection causes, or a marker for not validated yet.'
);

$HTTP_RAW_POST_DATA = isset($HTTP_RAW_POST_DATA) ? $HTTP_RAW_POST_DATA : "";
ob_clean();
$server->service($HTTP_RAW_POST_DATA);