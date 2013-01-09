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
 * [OpenStego](http://openstego.sourceforge.net/)
 * [Camouflage 1.2.1](http://camouflage.unfiction.com/)


Usage
-----

    # zsteg -h

    Usage: zsteg [options] filename.png
    
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


License
-------
Released under the MIT License.  See the [LICENSE](https://github.com/zed-0xff/zsteg/blob/master/LICENSE.txt) file for further details.
