# TabNews Reader: notas da atualização

## Texto para a App Store ("O que há de novo")

Chegaram três jogos novos e uma tela de Jogos Dev de cara nova!

• Regex Golf: escreva a menor regex que pega as palavras certas e ignora as erradas, com um teclado próprio cheio de símbolos de regex.
• HTTP Status: qual código o servidor deveria responder em cada situação?
• Git Rescue: escolha o comando certo para sair de cada enrascada no Git.
• Nova tela de Jogos Dev: progresso do dia, sequência de dias jogados, botão "Continuar" e os desafios diários em grade.
• Big O ampliado: perguntas de caso médio, custo amortizado e memória extra, cada uma com uma etiqueta dizendo o que está sendo medido.
• Color Match agora mostra o código hex das cores, com rodadas para adivinhar a cor pelo hex. Sound Match mostra o nome das notas e tem uma rodada de "qual som é mais agudo?".
• Perfil reorganizado, com um cartão dos Jogos Dev que mostra o progresso do dia e um atalho para os rankings.
• Dicas de uso reescritas, no mesmo visual do onboarding.
• Login mais confiável: a sessão é conferida quando você volta ao app, e os votos avisam quando ela expirou.
• Correções: o botão "Entrar no TabNews" não respondia; havia um espaço vazio no aviso de novidades; alguns selos diziam "New" em vez de "Novo"; além de outros ajustes.

---

## Changelog completo

### Novidades
- **Três jogos novos**, com desafios diários, modo livre, onboarding e ranking no Game Center:
  - **Regex Golf**: casar as palavras de uma lista e evitar as da outra com a menor regex possível. Tem teclado próprio e compacto: duas linhas de símbolos de regex (`^ $ . * + ? | \ ( ) [ ] { } - , \d \w \s \b`), letras, números e símbolos, ⌫ (segurar apaga tudo), e a Dica fica na barra superior.
  - **HTTP Status**: qual status code responder em cada cenário.
  - **Git Rescue**: qual comando resolve cada situação no Git.
- **Nova tela dos Jogos Dev**:
  - Cabeçalho compacto com a sequência (🔥 N dias) e o progresso dos 6 diários.
  - Cartão "Continuar" com o próximo diário pendente, ou um aviso de dia completo com a contagem até os próximos.
  - Diários em grade de 2 colunas; os já jogados ficam esmaecidos e vão para o fim.
  - "Mais jogos" em uma linha horizontal: DevLeet, DevSpot, Color Match e Sound Match.
  - Os jogos abrem com uma animação de zoom a partir do cartão do Perfil.
- **Big O**:
  - Novos tipos de pergunta: tempo no pior caso, tempo no caso médio, tempo amortizado e memória extra.
  - Uma etiqueta acima da pergunta diz o que está sendo medido.
  - Banco ampliado: 45 desafios diários (+10) e 86 no modo livre (+22).
- **Color Match**:
  - O hex aparece em tempo real enquanto você escolhe a cor.
  - Na revelação, compara o hex do alvo com o seu.
  - As rodadas 2 e 4 são "Ler o hex": você vê o código e escolhe a cor certa entre 4.
- **Sound Match**:
  - As frequências aparecem com o nome da nota (ex.: 440 Hz · A4).
  - A rodada 3 é "qual foi mais agudo?".
- **Perfil reorganizado**:
  - O cartão dos Jogos Dev mostra o progresso diário e tem um atalho para os rankings.
  - Novas estatísticas de atividade e "membro desde".
  - A seção de conta aparece só para quem está logado.
- **Dicas de uso reescritas** no visual preto e branco do onboarding. São 6 dicas sobre o que existe hoje no app: menu ao segurar um post, destaques e anotações, Biblioteca, perfil de quem escreve, Jogos Dev e o aviso de app não oficial.

### Correções
- O botão "Entrar no TabNews" no Perfil não respondia ao toque.
- O aviso de novidades dos jogos tinha um espaço vazio embaixo.
- No hub dos jogos, o conteúdo ficava por baixo dos botões do topo ao rolar.
- Alguns selos mostravam "New" em vez de "Novo".
- No DevSpot, as palavras eram hifenizadas no cartão pequeno.
- Os links dos botões de chamada nos posts eram montados com a URL errada.
- No Sound Match, o tom sustentado agora começa exatamente na frequência certa.

### Melhorias técnicas e refactors
- **Autenticação**:
  - A sessão é conferida sempre que o app volta para o primeiro plano.
  - Voto com sessão expirada mostra uma mensagem clara.
  - Requisições não idempotentes não são mais repetidas automaticamente quando a falha é ambígua.
- **Feed**: o conteúdo dos posts carrega em paralelo, juntando os resultados com segurança e sem duplicatas.
- **Exclusão de conta**: faz logout e abre o pedido de exclusão por e-mail para o suporte do TabNews.
- **Limpeza**:
  - Removidas várias telas legadas que não eram usadas: login e cadastro via WebView, compositor de comentários, Digest, lista antiga de curtidos e componentes antigos do cabeçalho do post.
  - O resultado foi cerca de 1.400 linhas a menos.
- **Organização**:
  - SettingsView foi dividida em seções modulares.
  - O formato "membro desde" ficou compartilhado no model `User`.
  - As dicas reaproveitam o `OnboardingPageView`, e os antigos CoachMarks foram removidos.
  - A notificação `navigateToHome`, que não era mais usada, foi removida.
- **Menos ruído nos logs** do sistema de partículas.

### Pendências antes de publicar
- Criar no App Store Connect os rankings do Game Center: `tabnews.httpstatus.best`, `tabnews.gitrescue.best` e `tabnews.regexgolf.best`.
- Ajustar a versão (hoje `MARKETING_VERSION = 4.2`; o aviso de novidades está marcado como 4.0).
