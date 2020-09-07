analyze -format verilog {
/home/projects/ljohn/aarora1/samidh_internship2020/Internship_2020/floating_point/16_bit/fp16_multiplier_modif.v \
/home/projects/ljohn/aarora1/samidh_internship2020/Internship_2020/floating_point/32_bit/Stratix10/DSP_Slice/FpAddSub_single.modif.v \
/home/projects/ljohn/aarora1/samidh_internship2020/Internship_2020/floating_point/converter_fp/fp16_to_fp32.v \
/home/projects/ljohn/aarora1/samidh_internship2020/Internship_2020/floating_point/converter_fp/fp32_to_fp16.v \
../../8x8int8.4x4fp16.organized.combined.v
}
set link_library "/home/projects/ljohn/aarora1/cadence_gpdk/gsclib045_all_v4.4/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/fast_vdd1v0_basicCells.modif.db dw_foundation.sldb"
set target_library /home/projects/ljohn/aarora1/cadence_gpdk/gsclib045_all_v4.4/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/fast_vdd1v0_basicCells.modif.db
elaborate matmul_slice -architecture verilog -library DEFAULT
#elaborate processing_element -architecture verilog -library DEFAULT
#elaborate qadd -architecture verilog -library DEFAULT
link
uniquify
#set_implementation pparch u_add
#set_implementation pparch u_mult
#set_dp_smartgen_options -all_options auto -hierarchy -smart_compare true -optimize_for speed -sop2pos_transformation false
create_clock -name "clk" -period 3 -waveform { 0 1.5}  { clk  }
#set_operating_conditions -library gscl45nm typical
#remove_wire_load_model
#compile -exact_map
compile_ultra
uplevel #0 { check_design } >> Report.8x8int8.4x4fp16.check_design.txt
link
ungroup -all -flatten 
uplevel #0 { report_timing -path full -delay max -nworst 1 -max_paths 1 -significant_digits 2 -sort_by group } >> Report.8x8int8.4x4fp16.timing.max.txt
uplevel #0 { report_area -hierarchy } >> Report.8x8int8.4x4fp16.area.txt
exit