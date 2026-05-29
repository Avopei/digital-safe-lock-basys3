# Digital Safe Lock - Basys3

Proiect VHDL pentru placa **Basys3**: lacat digital cu butoane, debouncing, FSM, LED-uri si afisaj 7 segmente.

Codul proiectului este pastrat neschimbat. In acest repository sunt adaugate doar fisiere de organizare si rulare: `README.md`, `.gitignore`, `create_vivado_project.tcl` si workflow-ul GitHub Actions pentru verificare VHDL.

## Structura repository-ului

```text
.
├── src/
│   ├── safe_lock(2).vhd
│   ├── debouncer_pulse(2).vhd
│   └── driver7seg(2).vhd
├── constraints/
│   └── Basys3_safe_lock(1).xdc
├── docs/
│   └── Diagrame proiect scid.png
├── create_vivado_project.tcl
├── README.md
└── .gitignore
```

## Functionalitate

Fluxul principal:

```text
butoane -> debouncing -> FSM -> LED-uri + afisaj 7 segmente
```

Cod corect:

```text
btnU -> btnR -> btnD -> btnL
```

Mapare valori butoane in proiect:

```text
L = 0, U = 1, R = 2, D = 3
```

Dupa 3 incercari gresite, lacatul intra in starea `LOCKED` timp de 10 secunde.

## Intrari si iesiri pe Basys3

Top entity: `safe_lock`

Porturi principale:

```text
clk, rst, btnL, btnU, btnR, btnD, led[15:0], seg[0:6], dp, an[3:0]
```

Resetul este pe `btnC`, conectat in constraint file la portul `rst`.

## Rulare in Vivado

### Varianta 1: folosind scriptul TCL

1. Deschide Vivado.
2. Din Tcl Console, ruleaza:

```tcl
cd <calea_catre_repository>
source create_vivado_project.tcl
```

Scriptul creeaza un proiect Vivado pentru placa Basys3 / Artix-7 si adauga automat sursele VHDL + fisierul XDC.

### Varianta 2: manual in Vivado

1. Creeaza un proiect nou RTL Project.
2. Selecteaza part-ul pentru Basys3:

```text
xc7a35tcpg236-1
```

3. Adauga sursele din folderul `src/`.
4. Adauga constraint file-ul din folderul `constraints/`.
5. Seteaza top module/entity: `safe_lock`.
6. Ruleaza Synthesis, Implementation si Generate Bitstream.
7. Programeaza placa Basys3.

## Verificare pe placa

1. Apasa `btnC` pentru reset.
2. Introdu codul corect: `btnU`, `btnR`, `btnD`, `btnL`.
3. La cod corect:
   - afisajul arata `1111`
   - LED-urile arata `00FF`
4. La cod gresit:
   - afisajul arata `000F`
   - LED-urile clipesc
5. Dupa 3 incercari gresite:
   - proiectul intra in `LOCKED`
   - afisajul face countdown 10 secunde
   - LED-urile arata `F000`

## GitHub Actions

Repository-ul include un workflow simplu care verifica analiza/elaborarea VHDL cu GHDL la fiecare push sau pull request.

Fisier:

```text
.github/workflows/vhdl-check.yml
```

Acest workflow este doar pentru verificare rapida de sintaxa/elaborare. Pentru generarea bitstream-ului foloseste Vivado.
