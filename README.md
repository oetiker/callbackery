CallBackery 0.2.0
=================

[![Build Status](https://travis-ci.org/oetiker/callbackery.svg?branch=master)](https://travis-ci.org/oetiker/callbackery)
[![Coverage Status](https://img.shields.io/coveralls/oetiker/callbackery.svg)](https://coveralls.io/r/oetiker/callbackery?branch=master)

CallBackery is a toolkit for CRUD style single page web applications with a desktopish look and feel.
For many applications, all you have todo is write a few lines of perl code and all the rest is taken care of by CallBackery.

To get you started, CallBackery comes with a sample application ... 

Quickstart
----------
The following was tested on a fresh xubuntu 12.04 and 14.04 x64

```

# --------------------
# install dependencies
# --------------------
sudo apt-get install curl
sudo apt-get install automake

# -----------------------------------
# install mojo, set env, generate app
# -----------------------------------
PREFIX=$HOME/opt/mojolicious
export PERL_CPANM_HOME=$PREFIX
export PERL_CPANM_OPT="--local-lib $PREFIX"
export PERL5LIB=$PREFIX/lib/perl5
export PATH=$PREFIX/bin:$PATH
curl -L cpanmin.us \
  | perl - -n https://github.com/oetiker/callbackery/archive/master.tar.gz

# --------
# make app
# --------
mkdir -p ~/src
cd ~/src
mojo generate callbackery_app CbDemo
cd cbdemo

# ..continue reading README in demo/ (see below)
```

Et voilà, you are looking at your first CallBackery app. Have a look
at the README in the demo directory for further instructions.


Enjoy

Tobi Oetiker <tobi@oetiker.ch>
