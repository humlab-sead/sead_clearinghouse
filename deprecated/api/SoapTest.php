<?php

/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

namespace Test {

    require_once '../Vendor/nosoap/lib/nusoap.php';

    abstract class SoapTest {

        protected $soap_client;

        function __construct($wsdl_uri) {
            
            $this->soap_client = new nusoap_client($wsdl_uri, true);
            $error = $client->getError();
            if ($error) {
                throw new Exception("nusoap client creation error $error", 0, null);
            }
        }

        function call($endPointName, array $callParamenters) {
            $response = $this->soap_client->call($endPointName, $callParamenters);
            if ($client->fault) {
                return "Fault";
            } else {
                $error = $this->soap_client->getError();
                if ($error) {
                    $err = "Error2: " . $error;
                    return $err; //.  "\ndebug: " + $client->getDebug();
                } else {
                    return $response;
                }
            }
        }
        
        abstract function run();
    }

}
?>

