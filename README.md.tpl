zsteg
======


Description
-----------
detect stegano-hidden data in PNG & BMP


Installation
------------
    gem install zsteg


Detects:
--------
 * LSB steganography in PNG & BMP
 * zlib-compressed data
 * [OpenStego](http://openstego.sourceforge.net/)
 * [Camouflage 1.2.1](http://camouflage.unfiction.com/)
 * [LSB with The Eratosthenes set](http://wiki.cedricbonhomme.org/security:steganography)


Usage
-----

% zsteg -h

Examples
--------

### Simple LSB

% zsteg flower_rgb3.png

### Multi-result file

% zsteg cats.png

### wbStego even distributed

% zsteg wbstego/wbsteg_noenc_even.bmp 1b,lsb,bY -v

### wbStego encrypted

% zsteg wbstego/wbsteg_blowfish_pass_1.bmp 1b,lsb,bY -v

### zlib

% zsteg ndh2k12_sp113.bmp -b 1 -o yx -v

See also
--------
1. https://29a.ch/photo-forensics/
2. https://holloway.nz/steg/

License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zsteg/blob/master/LICENSE.txt) file for further details.
