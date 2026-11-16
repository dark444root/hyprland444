#!/usr/bin/env bash
# Una frase distinta cada día para el widget
frases=(
 "Cree en ti"
 "Paso a paso, pero sin parar"
 "Hoy es un buen día para empezar"
 "El código no se escribe solo"
 "Disciplina > motivación"
 "Hazlo con calma, pero hazlo"
 "Lo difícil vale la pena"
 "Sigue aprendiendo"
 "Pequeños avances, grandes logros"
 "Tú puedes con esto"
)
echo "${frases[$(( 10#$(date +%j) % ${#frases[@]} ))]}"
