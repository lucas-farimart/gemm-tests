#=========================================================================
# Script de Sintese Genus para Comparação de Aceleradores GEMM
#   Abordagem: Uma SRAM simulada + um Buffer DCL p 
#-------------------------------------------------------------------------
# Autor: Lucas Farias Martins
# Email: lucas.martins@ee.ufcg.edu.br
# Data:  25-08-2026
#=========================================================================

#-------------------------------------------------------------------------
# 1. CONFIGURAÇAO DE VARIAVEIS E CAMINHOS
#-------------------------------------------------------------------------
set TOP_MODULE "sram_dclb" 
set DESIGN_NAME "${TOP_MODULE}"

set LIB_PATH $env(HOME)/PDK/gsclib045/timing
set LEF_PATH $env(HOME)/PDK/gsclib045/lef
set QRC_PATH $env(HOME)/PDK/gsclib045/qrc

# Adicione aqui a biblioteca .lib da sua SRAM real (ex: sram_256x32.lib) 
# para que o Genus saiba a area/potência real da macro, nao de flip-flops.
set_db init_lib_search_path [list $LIB_PATH $LEF_PATH $QRC_PATH]
set_db library fast_vdd1v0_basicCells.lib
set_db lef_library {gsclib045_tech.lef gsclib045_macro.lef gsclib045_multibitsDFF.lef}

#-------------------------------------------------------------------------
# 2. LEITURA DO RTL
#   Ler o modelo comportamental de memória como BLACK BOX.
#   Isso impede que o Genus sintetize o array 'mem' como 256 Flip-Flops.
#   O Genus usara a area/potência definida no arquivo .lib da SRAM.
#-------------------------------------------------------------------------

set_db init_hdl_search_path "../sram_dclb/ ../aux_rtl/"
# read_hdl -sv -black_box mem_model.sv

# Ler os modulos reais do seu design
read_hdl -sv mem_model.sv \
             ${TOP_MODULE}.sv \
             dclb.sv \
             dclb_controller.sv \
             mem_controller.sv \
             booth_radix4.sv \
             requant_unit.sv

elaborate ${TOP_MODULE}

#-------------------------------------------------------------------------
# 3. RESTRIÇOES (TIMING)
#   Certifique-se de ter um arquivo SDC especifico ou um generico 
#   que sirva para ambos
#-------------------------------------------------------------------------
read_sdc "../constraints/${TOP_MODULE}.sdc"

#-------------------------------------------------------------------------
# 4. SINTESE
#   Recomendo 'medium' para uma otimizaçao justa. 'low' pode esconder 
#   ganhos reais da sua lógica.
#-------------------------------------------------------------------------
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic
syn_map
syn_opt

#-------------------------------------------------------------------------
# 5. LEITURA DE ATIVIDADE (SAIF) PARA POTENCIA REAL
#   O Xcelium deve ter gerado este arquivo durante a simulaçao Gate-Level.
#   Substitua 'u_dut' pelo nome exato da instância do seu DUT no testbench.
#-------------------------------------------------------------------------
set SAIF_FILE "../sim/${TOP_MODULE}_activity.saif"
if { [file exists $SAIF_FILE] } {
    puts "INFO: Lendo arquivo SAIF para cálculo de potencia dinâmica real..."
    read_saif -input $SAIF_FILE -instance u_dut
} else {
    puts "WARNING: Arquivo SAIF nao encontrado. A potencia dinâmica será baseada em estimativas (toggle rates padrão)."
}

#-------------------------------------------------------------------------
# 6. RELATÓRIOS (REPORTS)
#-------------------------------------------------------------------------
file mkdir reports outputs

report_timing -max_paths 10 > reports/${DESIGN_NAME}_timing.rpt
report_power > reports/${DESIGN_NAME}_power.rpt
report_area  > reports/${DESIGN_NAME}_area.rpt
report_qor   > reports/${DESIGN_NAME}_qor.rpt

#-------------------------------------------------------------------------
# 7. SAIDAS PARA FLUXO POSTERIOR (Innovus/Tempus)
#-------------------------------------------------------------------------
write_hdl > outputs/${DESIGN_NAME}_netlist.v
write_sdc > outputs/${DESIGN_NAME}_sdc.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > outputs/${DESIGN_NAME}_delays.sdf

puts "INFO: Sintese do ${DESIGN_NAME} concluida com sucesso."

exit