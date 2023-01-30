# Node MPC ecdsa (Under Development)

### Nodejs Wrapper for Zengo-X Multi Party Ecdsa library

his project is a NodeJS implementation of {t,n}-threshold ECDSA (elliptic curve digital signature algorithm) p2p network.

Written on Livescript but easily portable with any Nodejs Application.

Threshold ECDSA includes two protocols:

* Key Generation for creating secret shares.
* Signing for using the secret shares to generate a signature.
ECDSA is used extensively for crypto-currencies such as Bitcoin, Ethereum (secp256k1 curve), NEO (NIST P-256 curve) and much more. This library can be used to create MultiSig and ThresholdSig crypto wallet. For a full background on threshold signatures please read our Binance academy article [Threshold Signatures Explained](https://academy.binance.com/en/articles/threshold-signatures-explained)
 

### Motivation

* Popularity and ease of use: Node.js is a widely-used and well-documented platform, making it accessible to a large community of developers and easy to learn for new developers.
* Networking capabilities: Node.js is designed for building networked applications, making it a natural choice for implementing a P2P network.
* Performance: Node.js is known for its fast and efficient performance, especially when dealing with a large number of parallel connections.
* Modularity and Reusability: Node.js has a rich ecosystem of modules and libraries that can be easily used to build complex applications. This makes it easy to reuse existing code and components for building a threshold signature P2P network.

### Features

* Masterless P2P network
* Implemented in functional way on Javascript
* Use original Zengo-X rust libraries
* Local Proxy server to communicate with original Library 
* Secure connection between nodes by using Public-key cryptography
* Node a blockchain, easy to customize and make a governance on blockchain

### Status

Under heavy development

### Play with it

```sh

npm i livescript -g

lsc node.ls --help

```