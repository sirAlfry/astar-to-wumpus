"""Prepara i file del docente che NON sono nel repository.

Il simulatore e le mappe del docente sono materiale didattico del corso,
che non si puo' ridistribuire: per questo sono esclusi da git
(.gitignore). Per far girare il progetto:

  1. scarica l'archivio del simulatore dalla pagina del corso;
  2. copia wumpus.py, agent.clp, map1.json ed exit.gif in clips-wumpus/simulatore/;
  3. lancia, dalla cartella clips-wumpus:   python strumenti/prepara_file_docente.py

Lo script crea in mappe/:
  - map1.json                  copia della mappa fornita dal docente
  - m00_default_simulatore.json la mappa di default scritta dentro wumpus.py
"""
import json, os, shutil, sys

QUI = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.join(QUI, "..", "simulatore")
MAPPE = os.path.join(QUI, "..", "mappe")

if not os.path.exists(os.path.join(SIM, "wumpus.py")):
    sys.exit("Manca simulatore/wumpus.py: copia prima i file del simulatore (dalla pagina del corso) in clips-wumpus/simulatore/")

shutil.copy(os.path.join(SIM, "map1.json"), os.path.join(MAPPE, "map1.json"))

sys.path.insert(0, QUI)
from esegui_headless import wumpus          # importa il simulatore anche senza tkinter
w = wumpus.default_world()
mappa = {"descrizione": "Mappa di default di wumpus.py (usata se si lancia il simulatore senza -m).",
         "width": w.width, "height": w.height, "start": list(w.start),
         "walls": sorted(list(c) for c in w.walls), "pits": sorted(list(c) for c in w.pits),
         "wumpus": list(w.wumpus), "gold": list(w.gold), "max_steps": w.max_steps,
         "step_cost": w.step_cost, "death_cost": w.death_cost, "grab_reward": w.grab_reward,
         "end_on_grab": w.end_on_grab}
with open(os.path.join(MAPPE, "m00_default_simulatore.json"), "w") as f:
    json.dump(mappa, f, indent=1)
print("Creati mappe/map1.json e mappe/m00_default_simulatore.json")
