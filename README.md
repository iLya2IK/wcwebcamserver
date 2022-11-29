# REST Web Camera server

## Short description

The server operates in the REST architecture mode. The server can accept POST requests and respond with JSON objects. 
The server is designed to collect images from cameras (devices) and forwards messages between devices to control the periphery via an HTTP 2 connection.  
A detailed implementation of an external device based on "ESP32-CAM" is given in the example [webcamdevice (С)](https://github.com/iLya2IK/webcamdevice).
Library for convenient client work with the wcWebCamServer server via the JSON protocol is [wcwebcamclient_lib (С/С++)](https://github.com/iLya2IK/wcwebcamclient_lib).
The example of a desktop application for external device controlling and viewing images is [webcamclientviewer (Lazarus)](https://github.com/iLya2IK/webcamclientviewer).
An example of an Android application for controlling external devices, chatting and streaming is [wcwebcameracontrol (Java)](https://github.com/iLya2IK/wcwebcameracontrol).

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

## Additional libraries (to build from sources)
4. CommonUtils - you can download lpk and sources [here](https://github.com/iLya2IK/commonutils)
5. WCHTTPServer - you can download lpk and sources [here](https://github.com/iLya2IK/wchttpserver)

## Copyrights and contibutions
* [SQLite - database engine](https://www.sqlite.org)
* [OpenSSL - Cryptography and SSL/TLS Toolkit](https://www.openssl.org)
* [Zlib - Compression Library](https://zlib.net/)
* [CommonUtils - lightweight lists, collections, seqs and hashes, helping classes for sqlite3 extension, gz compression, data streams - Copyright (c) 2018-2021, Ilya Medvedkov](https://github.com/iLya2IK/commonutils)
* [WCHTTPServer - Copyright (c) 2020-2021, Ilya Medvedkov](https://github.com/iLya2IK/wchttpserver)
