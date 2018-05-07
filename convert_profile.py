#!/usr/bin/env python2

# convert_profile.py: A simple script to convert image profiles to sRGB and uncompress.

import argparse
import os

from PIL import Image
from PIL.ImageCms import profileToProfile, createProfile

def parse_args():
    parser = argparse.ArgumentParser(description = 'Convert an input image to sRGB and uncompressed TIFF')
    parser.add_argument('input_image', help = 'Image file to convert')
    parser.add_argument('--output', help = 'Name of output file', default = 'output.tif')
    args = vars(parser.parse_args())
    return args

def convert_image(image_path):
    # Take an image pathname
    # Returns an Image object with the profile converted
    img = Image.open(image_path)

    # If there is an embedded profile, write it and use it for conversion
    if 'icc_profile' in img.info:

        with open('/tmp/profile.icc','wb') as f:
            f.write(img.info.get('icc_profile'))
        result = profileToProfile(img,'/tmp/profile.icc','sRGB.icm', outputMode='RGB')
        return result

    elif 'CMYK' in img.mode:
        result = profileToProfile(img,'CMYK.icc','sRGB.icm',outputMode='RGB')
        return result

    else:  
        return img

def main():
    args = parse_args()
    converted = convert_image(args['input_image'])
    converted.save(args['output'], compression = "None")

if __name__ == "__main__":
    main()

