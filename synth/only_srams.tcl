#=========================================================================
# Script de Sintese Genus para Comparacao de Aceleradores GEMM
#   Abordagem: Duas memorias SRAM simuladas 
#-------------------------------------------------------------------------
# Autor: Lucas Farias Martins
# Email: lucas.martins@ee.ufcg.edu.br
# Data:  25-08-2026
#=========================================================================

#-------------------------------------------------------------------------
# 1. CONFIGURACAO DE VARIAVEIS
#-------------------------------------------------------------------------
set TOP_MODULE "only_srams" 
set DESIGN_NAME "${TOP_MODULE}"

set LIB_PATH $env(HOME)/PDK/gsclib045/timing
set LEF_PATH $env(HOME)/PDK/gsclib045/lef
set QRC_PATH $env(HOME)/PDK/gsclib045/qrc

# Supressor de warnings nao preocupantes
# source ./suppress_warns.tcl

# Adicionar aqui a lib de uma SRAM real (ex: sram_256x32.lib) 
# assim, o Genus sabe a area/potência real da macro, nao de flip-flops.
set_db init_lib_search_path [list $LIB_PATH $LEF_PATH $QRC_PATH]
set_db library fast_vdd1v0_basicCells.lib
set_db lef_library {gsclib045_tech.lef gsclib045_macro.lef gsclib045_multibitsDFF.lef}

#-------------------------------------------------------------------------
# 2. LEITURA DO RTL
#   Ler o modelo comportamental de memoria como BLACK BOX.
#   Isso impede que o Genus sintetize o array 'mem' como 256 Flip-Flops.
#   O Genus usara a area/potencia definida no arquivo .lib da SRAM.
#-------------------------------------------------------------------------
set_db init_hdl_search_path "../only_srams/ ../aux_rtl/"
# read_hdl -sv -black_box mem_model.sv

read_hdl -sv ${TOP_MODULE}.sv mem_model.sv mem_controller.sv booth_radix4.sv requant_unit.sv

elaborate ${TOP_MODULE}

# set_db current_design only_srams

#-------------------------------------------------------------------------
# 3. RESTRIÇOES (TIMING)
#-------------------------------------------------------------------------
read_sdc "../constraints/${TOP_MODULE}.sdc"

#-------------------------------------------------------------------------
# 4. SINTESE
#-------------------------------------------------------------------------
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic
syn_map
syn_opt

#-------------------------------------------------------------------------
# 5. LEITURA DE ATIVIDADE (SAIF) - OPCIONAL
#-------------------------------------------------------------------------
set SAIF_FILE "../sim/${TOP_MODULE}_activity.saif"
if { [file exists $SAIF_FILE] } {
    puts "INFO: Lendo arquivo SAIF para cálculo de potência dinâmica real..."
    read_saif -input $SAIF_FILE -instance u_dut
} else {
    puts "WARNING: Arquivo SAIF não encontrado. A potência será estimada."
}

#-------------------------------------------------------------------------
# 6. RELATORIOS
#-------------------------------------------------------------------------
file mkdir reports outputs

# report_timing > reports/${DESIGN_NAME}_timing.rpt
report_timing -max_paths 10 > reports/${DESIGN_NAME}_timing.rpt
report_power  > reports/${DESIGN_NAME}_power.rpt
report_area   > reports/${DESIGN_NAME}_area.rpt
report_qor    > reports/${DESIGN_NAME}_qor.rpt

#-------------------------------------------------------------------------
# 7. SAIDAS PARA FLUXO POSTERIOR (Innovus/Tempus)
#-------------------------------------------------------------------------
write_hdl > outputs/${DESIGN_NAME}_netlist.v
write_sdc > outputs/${DESIGN_NAME}_sdc.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > outputs/${DESIGN_NAME}_delays.sdf

puts "INFO: Sintese do ${DESIGN_NAME} concluida com sucesso."

exit