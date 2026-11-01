onerror {quit -code 1}
if {![file exists work]} {vlib work}
vlog -work work ../rtl/*.v text_reference.v tb_stabilizer.v tb_merge.v tb_sccb.v tb_text.v tb_components.v tb_classifier.v tb_video.v tb_engine.v tb_photos.v tb_shadows.v tb_top.v
foreach test {tb_stabilizer tb_merge tb_sccb tb_text tb_components tb_classifier tb_video tb_engine tb_photos tb_shadows tb_top tb_top_stable} {
    vsim -t 1ps work.$test
    onfinish stop
    run -all
    quit -sim
}
puts "Finished: require TWELVE PASS lines and no FAIL."
