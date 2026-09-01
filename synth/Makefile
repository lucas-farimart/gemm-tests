
BUILD_DIR  = xcelium.d
WAVE_DIR   = waves
XRUN       = xrun
XRUN_FLAGS = -sv -64 -access +rwc -timescale 1ns/1ns
WAVE_FLAGS = -input waves.tcl # ainda nao existe 

# Alvo padrao
all: synth-help
.PHONY: all synth-help synth-only synth-dclb

#============================================================================
#                           COMANDOS DE SINTESE
#============================================================================

synth-help:
	@echo " "            
	@echo "|------------------------------------------|"   
	@echo "|                                          |"                       
	@echo "|    ()           _|_ |)    _  ,  o  ,     |"
	@echo "|    /\ |  | /|/|  |  |/\  |/ / \_| / \_   |"
	@echo "|   /(_) \/|/ | |_/|_/|  |/|_/ \/ |/ \/    |"
	@echo "|         (|                               |"
	@echo "|                                          |"                       
	@echo "|---------------------|--------------------|" 
	@echo "|       SINTESE       |    COMANDO MAKE    |"
	@echo "|---------------------|--------------------|"
	@echo "| SRAM com FFs        |   synth-simple     |"
	@echo "| SRAM como macro     |   synth-realmem    |"
	@echo "|---------------------|--------------------|"
	@echo "" 

# Sintetisando memoria como array de FFs
synth-only:
	rm -rf only.*
	clear
	genus -files only_srams.tcl -log only.log

# Sintetisando memoria como array de FFs
synth-dclb:
	rm -rf dclb.*
	clear
	genus -files sram_dclb.tcl -log dclb.log