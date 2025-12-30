Belts
    * Conectar esteiras nas saídas dos miners
    * Conexão de esteiras: conseguir construir uma esteira que conecta com outra, se tornando um BeltPath único (merge)
      * Continuar construindo a partir do ultimo node do ultimo beltpath spawmado - OK
      * O início no final de outra esteira (OK)
      * O início no meio de outra esteira - PROGRESS
        * dividir esteira original em duas 
        * e adicionar novos nós na primeiro seção da esteira antiga a partir do start node
      * O final no início de outra esteira
      * O final no meio de outra esteira (conexão T) 
    * Desconstruir nó de esteira (unmerge): habilidade de remover um nó da esteira, ou a esteira completa
    * Atualizar modelos da esteira para usar versões Straight, CurveLeft e CurveRight de acordo com as propriedades de cada node

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