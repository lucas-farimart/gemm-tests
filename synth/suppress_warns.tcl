#=========================================================================
# Supressor de warnings nao preocupantes
#-------------------------------------------------------------------------
# -suppress : elimina qualquer mensagem com o ID
# -severity : rebaixa a severidade 
# -limit N  : limita para N mensagens
#=========================================================================

set_msg_config -id LBR-9 -severity info
set_msg_config -id PHYS-129 -limit 1
set_msg_config -id PHYS-107 -limit 1
set_msg_config -id PHYS-279 -limit 1