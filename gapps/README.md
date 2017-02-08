# Getting the Gapps fro OpenGapps

Download a gapps bundle from [OpenGapps](http://opengapps.org)
For this version you need to select:
* Platform: ARM
* Android: 5.1
* Variant: pico

Put the downloaded zip file in this directory.

When you build trustme, the feature_gapps.img inside
the out-trustme/target/<device> iwould contain the gapps.
Otherwise an empty image will be generated.

