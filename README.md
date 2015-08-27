CallBackery 0.2.0
=================

[![Build Status](https://travis-ci.org/oetiker/callbackery.svg?branch=master)](https://travis-ci.org/oetiker/callbackery)
[![Coverage Status](https://img.shields.io/coveralls/oetiker/callbackery.svg)](https://coveralls.io/r/oetiker/callbackery?branch=master)

CallBackery is a perl library for writing CRUD style single page web
applications with a desktopish look and feel.  For many applications, all
you have todo is write a few lines of perl code and all the rest is taken
care of by CallBackery.

To get you started, CallBackery comes with a sample application ... 

Quickstart
----------

Open a terminal and follow these instructions below. We have tested them on
ubuntu 14.04 but they should work on any recent linux system with at least
perl 5.10.1 installed.

First make sure you have curl and automake installed. The following commands
will work on debian and ubuntu.  For redhat try `yum` instead of `apt-get`.

```
sudo apt-get install curl
sudo apt-get install automake
```

Now setup callbackery and all its requirements. You can set the `PREFIX` to
wherever you want callbackery to be installed.

```
PREFIX=$HOME/opt/callbackery
export PERL_CPANM_HOME=$PREFIX
export PERL_CPANM_OPT="--local-lib $PREFIX"
export PERL5LIB=$PREFIX/lib/perl5
export PATH=$PREFIX/bin:$PATH
curl -L cpanmin.us \
  | perl - -n https://github.com/oetiker/callbackery/archive/master.tar.gz
```

Finally lets generate the CallBackery sample application.

````
mkdir -p ~/src
cd ~/src
mojo generate callbackery_app CbDemo
cd cb_demo
```

Et voilà, you are looking at your first CallBackery app. To get the
sample application up and running, follow the instructions in the 
README you find in the `cb_demo` directory.


Enjoy

Tobi Oetiker <tobi@oetiker.ch>
