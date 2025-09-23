
# Esto es un separador de períodos ajustable de código abierto (open source) para Metatrader 5.

Su función es la de separar los períodos, exactamente igual a como lo hace el separador de períodos nativo de metatrader, pero con una diferencia. Lo hace ajustando los períodos a las aperturas estándard del horario regional Eastern Standard Time (US & Canada).

Esto por mucho tiempo no lo pudimos ver, ya que no contábamos con un camino para automatizar el cálculo del cambio de horarios entre hora de invierno y hora de verano, o Daylight Savings. Normalmente las lógicas que se implementaban en los separadores de períodos ajustables o dinámicos era el de ofrecer como input configurable un offset relativo al horario del servidor...

Ejemplo: Si el metatrader de mi broker tiene como su horario regional las GMT+2, entonces tendríamos que calcular cuántas horas de distancia habrían para llegar a Eastern Standard Time, e inputar eso en el indicador clásico. Y, según la fecha del año, sería necesario reajustar manualmente este offset dos veces cada año, según DST comienza y termina.

Este indicador resuelve este problema, utilizando una librería de código abierto publicada recientemente donde se calculan y estipulan valores para las fechas precisas UTC donde corresponde ajustar horarios por Daylight Savings. El único input que tenemos que indicar es cuál es el horario que está utilizando nuestro broker. Con este valor, la lógica del indicador calcula dónde está UTC/GMT -0 relativo a nuestro servidor del broker. Y a partir de ahí, configura el offset para ajustar ese valor a horario Eastern Standard, y lo hace teniendo en cuenta esas fechas y hora UTC donde es necesario ajustar ese cálculo para Daylight Savings, que están presentes en la librería.

Así, logramos que el indicador marque correctamente la medianoche New York todo el año, con precisión histórica (cuenta con el cálculo retrospectivo de DST hacia el año 2007), y sin necesidad de reajustar manualmente.
