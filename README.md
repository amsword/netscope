# Netscope CNN Analyzer

This is a CNN Analyzer tool, based on Netscope by [ethereon](https://github.com/ethereon).
Netscope is a web-based tool for visualizing neural network topologies. It currently supports UC Berkeley's [Caffe framework](https://github.com/bvlc/caffe).

This fork adds analysis capabilities, enabling the computation of network complexity (number of operations) and network size (number of parameters) for easy comparison of different networks.

### Run it locally
1. Install dependencies
```shell=
sudo apt-get install npm
npm install http-server -g
```
2. download the source code
```shell=
git clone http://github.com/amsword/netscope.git
```
3. start the server
```shell=
cd netscope
http-server
```
If you get the error of /usr/bin/env: node: No such file or directory, please run the following 
```shell=
sudo ln -s /usr/bin/nodejs /usr/bin/node
```

### Documentation
- Netscope [Quick Start Guide](http://dgschwend.github.io/netscope/quickstart.html)

### Demo
- :new: [Visualization of ZynqNet CNN](http://dgschwend.github.io/netscope/#/preset/zynqnet)
- [Visualization of the Deep Convolutional Neural Network "SqueezeNet"](http://dgschwend.github.io/netscope/#/preset/squeezenet)

### License

Released under the MIT license.
All included network models provided under their respective licenses.
