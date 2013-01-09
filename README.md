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


Usage
-----

    # zsteg -h

    Usage: zsteg [options] filename.png [param_string]
    
        -c, --channels X                 channels (R/G/B/A) or any combination, comma separated
                                         valid values: r,g,b,a,rg,rgb,bgr,rgba,...
        -l, --limit N                    limit bytes checked, 0 = no limit (default: 256)
        -b, --bits N                     number of bits (1..8), single value or '1,3,5' or '1-8'
            --lsb                        least significant BIT comes first
            --msb                        most significant BIT comes first
        -o, --order X                    pixel iteration order (default: 'auto')
                                         valid values: ALL,xy,yx,XY,YX,xY,Xy,bY,...
        -E, --extract NAME               extract specified payload, NAME is like '1b,rgb,lsb'
    
        -v, --verbose                    Run verbosely (can be used multiple times)
        -q, --quiet                      Silent any warnings (can be used multiple times)
        -C, --[no-]color                 Force (or disable) color output (default: auto)
    
    PARAMS SHORTCUT
    	zsteg fname.png 2b,b,lsb,xy  ==>  --bits 2 --channel b --lsb --order xy

Examples
--------

### Simple LSB

    # zsteg flower_rgb3.png

    [.] 1b,g,msb,xy   .. text: "05"
    [.] 1b,b,lsb,xy   .. text: "vs"
    [.] 2b,g,lsb,xy   .. text: "\"zfx"
    [.] 3b,rgb,lsb,xy .. text: "SuperSecretMessage"

### Multi-result file

    # zsteg cats.png

    [.] meta F        .. ["Z" repeated 14999985 times]
    [.] meta C        .. text: "Fourth and last cat is Luke"
    [.] meta A        .. [same as "meta F"]
    [.] meta date:create.. text: "2012-03-15T23:32:46+07:00"
    [.] meta date:modify.. text: "2012-03-15T23:32:14+07:00"
    [.] 1b,r,lsb,xy   .. text: "Second cat is Marussia"
    [.] 1b,g,lsb,xy   .. text: "Good, but look a bit deeper..."
    [.] 1b,bgr,lsb,xy .. text: "MF_WIhf>"
    [.] 2b,g,lsb,xy   .. text: "VHello, third kitten is Bessy"

### wbStego simple

    # zsteg wbsteg_noenc.bmp 1b,lsb,bY -v

    [.] 1b,lsb,bY     .. <wbStego size=22, ext="txt", data="SuperSecretMessage\n", even=false>
        00000000: 16 00 00 74 78 74 53 75  70 65 72 53 65 63 72 65  |...txtSuperSecre|
        00000010: 74 4d 65 73 73 61 67 65  0a                       |tMessage.       |

### wbStego even distributed

    # zsteg wbsteg_noenc_even.bmp 1b,lsb,bY -v

    [.] 1b,lsb,bY     .. <wbStego size=22, ext="txt", data="SuperSecretMessage\n", even=true>
        00000000: 51 00 00 16 00 00 74 0d  b5 78 1e a1 39 74 e8 38  |Q.....t..x..9t.8|
        00000010: 53 c6 56 94 75 d1 a5 70  84 c8 27 65 fe 08 72 35  |S.V.u..p..'e..r5|
        00000020: 1f 3e 53 5d a7 65 8b 6e  3b 63 6b 1d bf 72 ee 27  |.>S].e.n;ck..r.'|
        00000030: 65 8d ee 82 74 da 8d 4d  b3 8a 06 65 7e f8 73 9c  |e...t..M...e~.s.|
        00000040: 36 0c 73 aa bd 61 67 29  37 67 5f 0b 06 65 1f a4  |6.s..ag)7g_..e..|
        00000050: 0a a1 f8 35                                       |...5            |

License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zsteg/blob/master/LICENSE.txt) file for further details.
