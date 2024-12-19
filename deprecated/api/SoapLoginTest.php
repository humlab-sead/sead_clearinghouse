<?php

/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

namespace Test {
    
    class SoapLoginTest extends \Test\SoapTest {
        
        function __construct() {
            parent::__construct('http://snares.idesam.umu.se/sead/upload/CHSystem/api/Application/Soap/doLogin.php?wsdl');
        }
        
        private function runTest($user, $password){
            return parent::call('doLogin', array('user'=>$user, 'password' => $password));
        }

        public function run() {
            echo "soap login test:";
            echo "Test 1 (should fail, wrong password): ";
            echo $this->runTest('test_reader', 'hhhhgg');
            echo "\n";
            echo "Test 2 (should fail, unknown user): ";
            echo $this->runTest('mn', 'mnnb');
            echo "\n";
            echo "Test 3 (should succeed): ";
            echo $this->runTest('test_reader', 'secret');
            echo "\n";
        }

    }
    
    class SoapUploadTest extends \Test\SoapTest {
        
        function __construct() {
            parent::__construct('http://snares.idesam.umu.se/sead/upload/CHSystem/api/Application/Soap/doUpload.php?wsdl');
        }
        
        private function innerRun($user, $password, $fileContent){
            return parent::call('doUpload', array(
                'user' => $user,
                'password' => $password,
                'file' => $fileContent,
                'datatypes' => 'ALL'));
        }
        
        public function run() {
            echo "soap upload tests";
            echo "Test 1 (wrong user / password - fail): ";
            echo $this->innerRun('test_r', 'mnbjkk', 'kjhsdfkjsdhf');
            echo "\n";
            echo "Test 2 (user not allowed to upload - fail): ";
            echo $this->innerRun('test_reader', 'secret', 'kjhsdfkjsdhf');
            echo "\n";
            echo "Test 3 (upload successful - success): ";
            echo $this->innerRun('test_reader', 'secret', 'H4sIAAAAAAAAAA==');
            echo "\n";
        }
    }
    
    class SoapGetResultTest extends \Test\SoapTest {
        
        function __construct(){
            parent::__('http://snares.idesam.umu.se/sead/upload/CHSystem/api/Application/Soap/getResult.php?wsdl');
        }
        
        private function innerRun($user, $password, $submissionId){
            return parent::call('getResult', array (
                'user' => $user, 
                'password' => $password,
                'submissionId' => $submissionId
                ));
        }
        
        public function run(){
            echo "Test 1 (login fail): ";
            echo $this->innerRun('me', 'bark', '-1'); // fail
            echo "\n";

            echo "test 2 (login success, no submission) ";
            echo $this->innerRun('test_normal', 'secret', '1'); // fail
            echo "\n";

            echo "test 3 (login success, found submission, wrong user) ";
            echo $this->innerRun('test_reader', 'secret', '28'); // fail
            echo "\n";

            echo "test 4 (login success, found submission, not validated) ";
            echo $this->innerRun('test_normal', 'secret', '28'); // fail
            echo "\n";
        }
    }
}