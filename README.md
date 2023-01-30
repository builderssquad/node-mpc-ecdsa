# Node MPC ecdsa (Under Development)

### Nodejs Wrapper for Zengo-X Multi Party Ecdsa library

his project is a NodeJS implementation of {t,n}-threshold ECDSA (elliptic curve digital signature algorithm) p2p network.

Written on Livescript but easily portable with any Nodejs Application.

Threshold ECDSA includes two protocols:

* Key Generation for creating secret shares.
* Signing for using the secret shares to generate a signature.
ECDSA is used extensively for crypto-currencies such as Bitcoin, Ethereum (secp256k1 curve), NEO (NIST P-256 curve) and much more. This library can be used to create MultiSig and ThresholdSig crypto wallet. For a full background on threshold signatures please read our Binance academy article [Threshold Signatures Explained](https://academy.binance.com/en/articles/threshold-signatures-explained)
 

### Play with it

```sh

npm i livescript -g

lsc node.ls --help

```