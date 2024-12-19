<?php

/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */


$old_default_socket_timeout = ini_get('default_socket_timeout');
$old_max_execution_time = ini_get('max_execution_time');

$params = array("trace" => true, "connection_timeout" => 5);

ini_set('max_execution_time', 1000); // just put a lot of time
ini_set('default_socket_timeout', 1000); // same

require_once __DIR__ . '/../../autoload.php';

$db = \InfraStructure\ConnectionFactory::Create(array(
    "hostname" => "",
    "port" => "12343",
    "username" => "",
    "password" => "",
    "database" => "")
);

try {

    throw Exception("This service is deprecated!");

    $data = $db->fetch_first("select * From facet.tbl_upload_contents where upload_content_id = 81", null);

    $client = new SoapClient('http://127.0.0.1/SEAD_ClearingHouse/public/api/Application/Soap/doUpload.wsdl', $params);

    //$result = $client->__soapCall('doUpload', array('user' => 'test_normal', 'password' => 'secret', 'file' => $data["upload_contents"], 'datatypes' =>  $data["upload_data_types"]));

    $result = $client->doUpload(array('user' => 'test_normal', 'password' => 'secret', 'file' => $data["upload_contents"], 'datatypes' =>  $data["upload_data_types"]));

} catch (Exception $ex) {
    echo $ex->getMessage();
}

echo $result;


ini_set('default_socket_timeout', $old_default_socket_timeout);
ini_set('max_execution_time', $old_max_execution_time);