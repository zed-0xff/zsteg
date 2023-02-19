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

    # zsteg -h

    Usage: zsteg [options] filename.png [param_string]
    
        -a, --all                        try all known methods
        -E, --extract NAME               extract specified payload, NAME is like '1b,rgb,lsb'
    
    Iteration/extraction params:
        -o, --order X                    pixel iteration order (default: 'auto')
                                         valid values: ALL,xy,yx,XY,YX,xY,Xy,bY,...
        -c, --channels X                 channels (R/G/B/A) or any combination, comma separated
                                         valid values: r,g,b,a,rg,bgr,rgba,r3g2b3,...
        -b, --bits N                     number of bits, single int value or '1,3,5' or range '1-8'
                                         advanced: specify individual bits like '00001110' or '0x88'
            --lsb                        least significant bit comes first
            --msb                        most significant bit comes first
        -P, --prime                      analyze/extract only prime bytes/pixels
            --shift N                    prepend N zero bits
            --step N                     step
            --invert                     invert bits (XOR 0xff)
            --pixel-align                pixel-align hidden data
    
    Analysis params:
        -l, --limit N                    limit bytes checked, 0 = no limit (default: 256)
    
            --[no-]file                  use 'file' command to detect data type (default: YES)
            --no-strings                 disable ASCII strings finding (default: enabled)
        -s, --strings X                  ASCII strings find mode: first, all, longest, none
                                         (default: first)
        -n, --min-str-len X              minimum string length (default: 8)
    
        -v, --verbose                    Run verbosely (can be used multiple times)
        -q, --quiet                      Silent any warnings (can be used multiple times)
        -C, --[no-]color                 Force (or disable) color output (default: auto)
    
    PARAMS SHORTCUT
    	zsteg fname.png 2b,b,lsb,xy  ==>  --bits 2 --channel b --lsb --order xy

Examples
--------

### Simple LSB

    # zsteg flower_rgb3.png

    imagedata           .. file: 370 XA sysV pure executable not stripped - version 768
    b3,rgb,lsb,xy       .. text: "SuperSecretMessage"

### Multi-result file

    # zsteg cats.png

    meta F              .. ["Z" repeated 14999985 times]
    meta C              .. text: "Fourth and last cat is Luke"
    meta A              .. [same as "meta F"]
    meta date:create    .. text: "2012-03-15T23:32:46+07:00"
    meta date:modify    .. text: "2012-03-15T23:32:14+07:00"
    imagedata           .. file: 68K BCS executable
    b1,r,lsb,xy         .. text: "Second cat is Marussia"
    b1,g,lsb,xy         .. text: "Good, but look a bit deeper..."
    b1,bgr,lsb,xy       .. text: "MF_WIhf>"
    b2,g,lsb,xy         .. text: "VHello, third kitten is Bessy"

### wbStego even distributed

    # zsteg wbstego/wbsteg_noenc_even.bmp 1b,lsb,bY -v

    b1,lsb,bY           .. <wbStego size=22, data="xtSuperSecretMessage\n", even=true, mix=true, controlbyte="t">
        00000000: 51 00 00 16 00 00 74 0d  b5 78 1e a1 39 74 e8 38  |Q.....t..x..9t.8|
        00000010: 53 c6 56 94 75 d1 a5 70  84 c8 27 65 fe 08 72 35  |S.V.u..p..'e..r5|
        00000020: 1f 3e 53 5d a7 65 8b 6e  3b 63 6b 1d bf 72 ee 27  |.>S].e.n;ck..r.'|
        00000030: 65 8d ee 82 74 da 8d 4d  b3 8a 06 65 7e f8 73 9c  |e...t..M...e~.s.|
        00000040: 36 0c 73 aa bd 61 67 29  37 67 5f 0b 06 65 1f a4  |6.s..ag)7g_..e..|
        00000050: 0a a1 f8 35                                       |...5            |

### wbStego encrypted

    # zsteg wbstego/wbsteg_blowfish_pass_1.bmp 1b,lsb,bY -v

    b1,lsb,bY           .. <wbStego size=26, data="\rC\xF5\xBF#\xFF[6\e\xB3"..., even=false, hdr="\x01", enc="Blowfish">
        00000000: 1a 00 00 00 ff 01 01 0d  43 f5 bf 23 ff 5b 36 1b  |........C..#.[6.|
        00000010: b3 17 42 4a 3f ba eb c7  ee 9c d7 7a 2b           |..BJ?......z+   |

### zlib

    # zsteg ndh2k12_sp113.bmp -b 1 -o yx -v

    b1,rgb,lsb,yx       .. zlib: data="%PDF-1.4\n%\xC3\xA4\xC3\xBC\xC3\xB6\xC3\x9F\n2 0 obj\n<</Length 3 0 R/Filter/FlateDecode>>\nstream\nx\x9C\x8DT\xC9n\xDB@\f\xBD\xCFW\xF0\x1C \x13\x92\xB3\x03\x86\x80\xC8K\xD1\xDE\\\b\xE8\xA1...", offset=4, size=186
        00000000: 00 02 eb 9b 78 9c d4 b9  65 54 24 cc 92 36 58 b8  |....x...eT$..6X.|
        00000010: d3 68 e3 ee ee 4e e3 ee  ee 0e 85 bb 3b dd 68 23  |.h...N......;.h#|
        00000020: 8d bb bb bb 3b 8d bb bb  3b 34 ee 6e 1f ef 7b ef  |....;...;4.n..{.|
        00000030: 9d 3b b3 e7 cc 9e d9 3d  df 9e dd cd 8a 1f 99 19  |.;.....=........|
        00000040: 99 55 11 99 4f 58 25 99  82 88 18 1d 13 3d 2b 2c  |.U..OX%......=+,|
        00000050: 59 6f 7e 6f 7b 6f 63 6f  16 2c 33 21 23 a1 9d 91  |Yo~o{oco.,3!#...|
        00000060: 25 2c 2f 2f 83 0c d0 d6  cc d9 9c 90 e5 73 46 89  |%,//.........sF.|
        00000070: 41 cc c2 da 19 e8 c8 20  66 6d e8 0c 14 01 1a db  |A...... fm......|
        00000080: 99 00 f9 f8 60 9d 9c 1d  81 86 36 b0 ee e9 bf 54  |....`.....6....T|
        00000090: 86 6d 57 05 e0 3b 26 d5  2f 71 09 51 63 eb c0 82  |.mW..;&./q.Qc...|
        000000a0: bf 0f 49 4f 6f e8 40 ff  c9 f9 43 25 1d 9e 6b 1b  |..IOo.@...C%..k.|
        000000b0: a3 73 fd 42 c4 a6 65 3d  ef 0a 07 32 17 2d dc f9  |.s.B..e=...2.-..|
        000000c0: 10 8c 0d 4b d7 9d e6 01  12 4f 11 6f f0 cd 64 f2  |...K.....O.o..d.|
        000000d0: f2 19 5c df 76 eb 01 49  dc fd cd 76 65 a2 3a 8a  |..\.v..I...ve.:.|
        000000e0: fd bb 13 a9 e6 3a c9 da  19 34 ae f0 43 bb 90 90  |.....:...4..C...|
        000000f0: 58 88 de 46 ce 91 6f aa  8d d9 7d b8 d6 88 a6 65  |X..F..o...}....e|

See also
--------
1. https://29a.ch/photo-forensics/
2. https://holloway.nz/steg/

License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zsteg/blob/master/LICENSE.txt) file for further details.
