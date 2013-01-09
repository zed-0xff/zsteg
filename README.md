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
    
    PARAMS SHORTCUT
    	zsteg fname.png 2b,b,lsb,xy  equal to --bits 2 --channel b --lsb --order xy

Examples
--------

### Simple LSB

    # zsteg flower_rgb3.png

    [1;30m[.] 1b,r,lsb,xy   .. [0m[1;30m[.] 1b,r,msb,xy   .. [0m[1;30m[.] 1b,g,lsb,xy   .. [0m[1;30m[.] 1b,g,msb,xy   .. [0m[1;30mtext: [0m[1;31m"05"[0m
    [1;30m[.] 1b,b,lsb,xy   .. [0m[1;30mtext: [0m[1;31m"vs"[0m
    [1;30m[.] 1b,b,msb,xy   .. [0m[1;30m[.] 1b,rgb,lsb,xy .. [0m[1;30m[.] 1b,rgb,msb,xy .. [0m[1;30m[.] 1b,bgr,lsb,xy .. [0m[1;30m[.] 1b,bgr,msb,xy .. [0m[1;30m[.] 2b,r,lsb,xy   .. [0m[1;30m[.] 2b,r,msb,xy   .. [0m[1;30m[.] 2b,g,lsb,xy   .. [0m[1;30mtext: [0m[1;31m"\"zfx"[0m
    [1;30m[.] 2b,g,msb,xy   .. [0m[1;30m[.] 2b,b,lsb,xy   .. [0m[1;30m[.] 2b,b,msb,xy   .. [0m[1;30m[.] 2b,rgb,lsb,xy .. [0m[1;30m[.] 2b,rgb,msb,xy .. [0m[1;30m[.] 2b,bgr,lsb,xy .. [0m[1;30m[.] 2b,bgr,msb,xy .. [0m[1;30m[.] 3b,r,lsb,xy   .. [0m[1;30m[.] 3b,r,msb,xy   .. [0m[1;30m[.] 3b,g,lsb,xy   .. [0m[1;30m[.] 3b,g,msb,xy   .. [0m[1;30m[.] 3b,b,lsb,xy   .. [0m[1;30m[.] 3b,b,msb,xy   .. [0m[1;30m[.] 3b,rgb,lsb,xy .. [0m[1;30mtext: [0m[1;31m"SuperSecretMessage"[0m
    [1;30m[.] 3b,rgb,msb,xy .. [0m[1;30m[.] 3b,bgr,lsb,xy .. [0m[1;30m[.] 3b,bgr,msb,xy .. [0m[1;30m[.] 4b,r,lsb,xy   .. [0m[1;30m[.] 4b,r,msb,xy   .. [0m[1;30m[.] 4b,g,lsb,xy   .. [0m[1;30m[.] 4b,g,msb,xy   .. [0m[1;30m[.] 4b,b,lsb,xy   .. [0m[1;30m[.] 4b,b,msb,xy   .. [0m[1;30m[.] 4b,rgb,lsb,xy .. [0m[1;30m[.] 4b,rgb,msb,xy .. [0m[1;30m[.] 4b,bgr,lsb,xy .. [0m[1;30m[.] 4b,bgr,msb,xy .. [0m

License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zsteg/blob/master/LICENSE.txt) file for further details.
