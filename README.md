
# 🗓️ Separador de períodos ajustable de código abierto (open source) para Metatrader 5.

Su función: separar los períodos. Exactamente igual a como lo hace el separador nativo de metatrader, pero con una diferencia. Este lo hace ajustando los períodos a las aperturas estándard del horario regional, Eastern Standard Time (US & Canada), ajustando por Daylight Savings.

La mayoría de los indicadores diseñados para separar períodos según horarios configurables, por lo general piden que establezcamos cuántas horas de desplazamiento (offset) quisiéramos que hayan entre "⏳ la apertura nativa de la terminal" y "⏲️ la apertura ajustada por el indicador". Como esta manera de plantearse las cosas pauta un input fijo, el indicador puede estar equivocado en la mitad de cada año dibujado... al entrar y salir de DST. El horario de invierno/verano hace más difícil marcar con precisión las aperturas a lo largo de todo el intraday chart-markup anual.

## 🌄 La solución: Librerías DST.
Se publicó una librería para mql5 en los fórums oficiales con el cálculo resuelto para los comienzos y cierres de DST americano y europeo. 

Este indicador actualmente se enfoca sobre el segmento DST americano de esa librería. La herramienta pide que pongamos como input cuál es el horario regional del servidor que estamos utilizando, o el metatrader de nuestro broker, y hace el cálculo de cuánto es necesario desplazar las líneas de apertura para llegar a las aperturas EST en ese mercado que queramos delimitar. Ajustando el offset cuando entramos y salimos de DST para que el indicador marque correctamente todos sus dibujos a través de los plazos anuales completos.

Así, logramos que el indicador marque correctamente la medianoche New York todo el año, con precisión histórica (contando con el cálculo retrospectivo de DST hasta el año 2007), y sin necesidad de reajustar manualmente.

## ♻️ ¿Qué pasa cuando los servidores ya ajustan?
En algunos brokers el ajuste por DST se sirve a nivel del servidor. Es decir, el horario "se acomodaría solo" y no necesitaríamos del indicador para esta tarea. Para esto se implementó también un toggle-switch que nos brinda la opción de "encendido/apagado del offset". Esto con la idea de lograr que el indicador sea lo más universalmente aplicable posible entre diferentes terminales de metatrader.

Ejemplo: Agregamos al indicador sobre nuestra pantalla, y le indicamos el horario de nuestro servidor. Supongamos que es GMT +2. Hasta ahí OK. Pero supongamos que, por ejemplo, nuestro broker TIMBEX ajustase sus servidores de Metatrader por DST por su propia cuenta, sirviendo un chart con DST ya ajustado. En este caso, ajustar nuevamente a nivel de nuestro indicador sería redundante. TIMBEX _ya lo está sirviendo_ ajustado. Y, si lo dejamos por defecto → vamos a tener un delimitado equivocado en el período DST nuevamente. No hay problema: Con un toggle, podemos "apagar" las fechas pautadas por la librería y evitar ese desplazamiento horario de las líneas corregidas en los meses del año correspondientes al período DST. El indicador aplica bajo cualquier clase de condiciones.

## 📝 Detalles importantes.
A nivel general funciona OK, aunque es posible que existan imprecisiones entre distintos brokers. Porque existe muchísima variedad de ellos que sirven terminales de metatrader con horarios propios, ajustados en toda una gama de variedades y, a pesar de que DST es universal, no todos lo reajustan ni lo respetan a la perfección...  Van a haber dos tipos de situaciones bajo las cuales el indicador es incapaz de pautar las New York Midnights perfectamente.
- Ejemplo: Tenemos al indicador marcando correctamente alineadas las aperturas de los últimos cinco años, pero a partir del 6to año y hacia atrás, al parecer el servidor (eg. 'TIMBEX'), todavía no ajustaba su horario regional para coincidir con DST. Entonces tendríamos una delimitación histórica de las medianoches que se desalinearía a partir de ese 6to año.

  ❎ El script no cuenta con una lógica donde podamos inputar años específicos para eximir del offset. Con el toggle → o ajustamos, o no lo hacemos. Pero no tenemos un termino medio para ajustar o no ajustar años determinados. Si miramos el suficiente tiempo hacia atrás, es probable que en algunos casos no obtengamos la línea pintada perfectamente.

Todo esto se podría parchar, pero acomplejizaría al script más de lo que personalmente lo necesitaba. En cualquier caso, está publicado libremente para que si se necesita, se implementen esos cambios.
