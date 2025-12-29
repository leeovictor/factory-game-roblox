Belts
    * Conexão de esteiras: conseguir construir uma esteira que conecta com outra, se tornando um BeltPath único (merge)
    * Conexão em T: habilidade de conectar logicamente duas BeltPath diferentes, onde o final de uma elas entra em um node da outra, transferindo items para ela 
    * Desconstruir nó de esteira (unmerge): habilidade de remover um nó da esteira, ou a esteira completa


GridLines render
    * Renderizar linhas de grade quando o player está construindo algo
    * Renderizar essas linhas nos 50/100 de distancia do player 
    * A medida que o player se move a grid se move junto, removendo linhas fora do alcance e criando novas para sempre manter as grid lines desenhadas proximas do player


Sorter: construção que coleta item de esteiras ou outras construções e transfere para outras esteiras ou construções
    * Criar modelo básico para o sorter
    * Implementar sistema de construção para o sorter
      * Clico para adicionar a conexão de entrada e depois finalizo a conexão de saída
      * Crio a entidade sorter atualiza as conexões relevantes para simulação
    * Criar sistema de simulação do sorter
      * Tem 3 estados
        * waiting_for_cargo: quando está esperando items da entrada (esteira ou facility)
        * transporting: quando está transportando um item em direção à entrada, tem um tempo definido
        * returning: quando a base do sorter está retornando a posição inicial da entrada
        * product_overflow: quando o processo de transporte foi finalizado, mas não é possível inserir o item na saída por conta de não haver espaço
      * Provavelmente vai interagir com esteiras e facilities, observando receitas selcionadas para compreender que tipo de items pode transportar naquele momento


