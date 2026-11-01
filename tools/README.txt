No Python is needed to compile the supplied Verilog in Quartus.
To reproduce the appended reference bank (Python 3, numpy, Pillow):
  python tools/rebuild_front_back.py
It reads the frozen V6.1 baseline plus six included front_back_source PNGs.
  python tools/make_photo_scenes.py
regenerates the 115 RGB565 regression scenes and software expectations.
The old 53-photo calibration builder is retained for its model functions;
its standalone entry point is disabled to avoid overwriting this release.
PDF monitor photographs are calibration, not raw sensor captures. Unknown
camera/exposure/photograph perspective affects how closely they match hardware.
