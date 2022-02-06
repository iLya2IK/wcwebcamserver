# REST Web Camera server

## Short description

The server operates in the REST architecture mode. The server can accept POST requests and respond with JSON objects. 
The server is designed to collect images from cameras (devices) and forwards messages between devices to control the periphery via an HTTP 2 connection. 
A detailed implementation of an external device based on "ESP32-CAM" is given in the example "webcamdevice".
An example of a desktop application for external device controlling and viewing images is "webcamclientviewer".

# How to deal with the server example?
* Build it using the necessary development environment and libraries or download precompiled release.
* Do not forget to generate a certificate and key file for your localhost (put them in ./openssl folder). 
* Command-line to start server: "wcwebcamserver {PORTNUM}" (PORTNUM - is a number of the listening port - 8080 for example)

## Development environment
Free Pascal (v3.2.0) + Lazarus (v2.0.10)

## Necessary libraries
1. SQLite
2. OpenSSL (v1.1.0 or higher)
3. Zlib
4. CommonUtils - you can download sources [here](https://github.com/iLya2IK/commonutils)
5. WCHTTPServer - you can download sources [here](https://github.com/iLya2IK/wchttpserver)

## Copyrights
* [CommonUtils - lightweight lists, collections, seqs and hashes, helping classes for sqlite3 extension, gz compression, data streams - Copyright (c) 2018-2021, Ilya Medvedkov](https://github.com/iLya2IK/commonutils)
* [WCHTTPServer - Copyright (c) 2020-2021, Ilya Medvedkov](https://github.com/iLya2IK/wchttpserver)
