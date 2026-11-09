import sys, os, json, subprocess, shutil
import logging
from logging.handlers import RotatingFileHandler
from typing import Optional
import textwrap

from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QLineEdit, QTextEdit, QComboBox, QPushButton,
    QFileDialog, QMessageBox, QGridLayout, QSpinBox, QDoubleSpinBox, QDateEdit,
    QTabWidget, QVBoxLayout, QMainWindow, QScrollArea, QSizePolicy,
    QSplashScreen, QDialog, QProgressDialog
)
from PyQt5.QtCore import QDate, Qt, QTimer, QProcess, QUrl
from PyQt5.QtGui import QPixmap, QIcon, QDesktopServices

# ========= LOGGING SETUP =========
def _ensure_dir(p: str):
    try:
        os.makedirs(p, exist_ok=True)
    except Exception:
        pass

def get_log_dir() -> str:
    """
    Restituisce sempre <APP_DIR>/logs
    - In sviluppo: cartella del file .py
    - In eseguibile PyInstaller: cartella dell'eseguibile
    """
    if getattr(sys, "frozen", False):  # PyInstaller
        app_dir = os.path.dirname(sys.executable)
    else:
        app_dir = os.path.dirname(os.path.abspath(__file__))

    local_logs = os.path.join(app_dir, "logs")
    os.makedirs(local_logs, exist_ok=True)
    return local_logs

def get_log_path() -> str:
    # Un file unico che ruota (max 5 MB x 5 backup)
    return os.path.join(get_log_dir(), "irisbiome.log")

def init_logger():
    logger = logging.getLogger("IrisBiome")
    logger.setLevel(logging.DEBUG)

    # Evita duplicati se init_logger() viene richiamato due volte
    if logger.handlers:
        return logger

    log_path = get_log_path()
    handler = RotatingFileHandler(log_path, maxBytes=5_000_000, backupCount=5, encoding="utf-8")
    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    handler.setFormatter(fmt)
    logger.addHandler(handler)

    # Console opzionale (livello INFO), utile in debug locale
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(fmt)
    logger.addHandler(console)

    logger.info("=== IrisBiome logger inizializzato ===")
    logger.info(f"File di log: {log_path}")
    return logger

# Istanzia il logger a livello modulo
LOGGER = init_logger()

def log_run_header(context: str, cmd: list, cwd: Optional[str]):
    LOGGER.info("-" * 80)
    LOGGER.info(f"[RUN] {context}")
    LOGGER.info(f"  CWD: {cwd or os.getcwd()}")
    LOGGER.info("  CMD: " + " ".join(map(str, cmd)))

def log_run_footer_ok(context: str):
    LOGGER.info(f"[OK] {context} completato")

def log_run_footer_fail(context: str, exit_code: Optional[int], stdout: str, stderr: str):
    LOGGER.error(f"[FAIL] {context} (exit_code={exit_code})")
    if stdout:
        LOGGER.error("--- STDOUT ---\n%s", stdout)
    if stderr:
        LOGGER.error("--- STDERR ---\n%s", stderr)


# ========= UTILS =========
def resource_path(rel_path: str) -> str:
    """Path assoluto a una risorsa. Funziona sia in dev che con PyInstaller."""
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        base = sys._MEIPASS  # type: ignore[attr-defined]
    else:
        base = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base, rel_path)

def default_database_path() -> str:
    return os.environ.get("IRISBIOME_DB_DIR", os.environ.get("FAUSTBIOME_DB_DIR", resource_path("database")))

def default_ncores() -> int:
    detected = os.cpu_count() or 1
    return max(1, min(4, detected - 1 if detected > 1 else 1))

def browse_file(lineedit, filter_str="Tutti i file (*.*)"):
    filename, _ = QFileDialog.getOpenFileName(None, "Seleziona file", "", filter_str)
    if filename:
        lineedit.setText(filename)

def browse_folder(lineedit):
    folder = QFileDialog.getExistingDirectory(None, "Seleziona cartella")
    if folder:
        lineedit.setText(folder)


# ========= ESECUZIONI SINCRONE (se mai ti servissero) =========
def run_command(cmd, parent, success_msg, fail_msg, cwd: Optional[str] = None, context: str = "REPORT"):
    log_run_header(context, cmd, cwd)
    try:
        res = subprocess.run(cmd, check=True, cwd=cwd, capture_output=True, text=True)
        if res.stdout:
            LOGGER.debug("[STDOUT][%s]\n%s", context, res.stdout.rstrip())
        if res.stderr:
            LOGGER.debug("[STDERR][%s]\n%s", context, res.stderr.rstrip())
        log_run_footer_ok(context)
        QMessageBox.information(parent, "OK", success_msg + f"\n\nLog: {get_log_path()}")
        return True
    except subprocess.CalledProcessError as e:
        out = e.stdout or ""
        err = e.stderr or ""
        log_run_footer_fail(context, e.returncode, out, err)
        ret = QMessageBox.critical(
            parent, "Errore",
            f"{fail_msg}.\nVuoi aprire il file di log?\n{get_log_path()}",
            QMessageBox.Yes | QMessageBox.No
        )
        if ret == QMessageBox.Yes:
            QDesktopServices.openUrl(QUrl.fromLocalFile(get_log_path()))
        return False
    except Exception:
        LOGGER.exception("[EXC] %s", context)
        ret = QMessageBox.critical(
            parent, "Errore",
            f"{fail_msg}.\nVuoi aprire il file di log?\n{get_log_path()}",
            QMessageBox.Yes | QMessageBox.No
        )
        if ret == QMessageBox.Yes:
            QDesktopServices.openUrl(QUrl.fromLocalFile(get_log_path()))
        return False


# ========= FORM ANAMNESI (non usato direttamente) =========
class AnamnesiForm(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Modulo Anamnestico")
        self.resize(900, 700)

        scroll = QScrollArea(self)
        scroll.setWidgetResizable(True)

        content = QWidget()
        layout = QGridLayout(content)
        # … qui potresti costruire un form separato …

        scroll.setWidget(content)
        main_layout = QVBoxLayout(self)
        main_layout.addWidget(scroll)
        self.setLayout(main_layout)


# ========= TAB PIPELINE =========
class PipelineTab(QWidget):
    def run_process_async(self, cmd, on_success=None, on_fail=None, cwd: Optional[str] = None,
                          title: str = "Running...", label_text: str = "Please wait...", context: str = "RUN"):
        # Disabilita bottoni
        for btn in getattr(self, "_action_buttons", []):
            btn.setEnabled(False)

        # Dialog progresso
        dlg = QProgressDialog(label_text, "Cancel", 0, 0, self)
        dlg.setWindowTitle(title)
        dlg.setWindowModality(Qt.WindowModal)
        dlg.setAutoClose(False)
        dlg.setAutoReset(False)
        dlg.setMinimumDuration(0)
        dlg.show()

        proc = QProcess(self)
        if cwd:
            proc.setWorkingDirectory(cwd)

        program, *args = cmd
        proc.setProgram(program)
        proc.setArguments(args)

        # Buffer e logging header
        self._last_stdout = b""
        self._last_stderr = b""
        log_run_header(context, [program] + args, cwd)

        def _read_out():
            chunk = proc.readAllStandardOutput().data()
            if chunk:
                self._last_stdout += chunk
                try:
                    LOGGER.debug("[STDOUT][%s] %s", context, chunk.decode(errors="ignore").rstrip())
                except Exception:
                    pass

        def _read_err():
            chunk = proc.readAllStandardError().data()
            if chunk:
                self._last_stderr += chunk
                try:
                    LOGGER.debug("[STDERR][%s] %s", context, chunk.decode(errors="ignore").rstrip())
                except Exception:
                    pass

        proc.readyReadStandardOutput.connect(_read_out)
        proc.readyReadStandardError.connect(_read_err)

        def _finish(exit_code, exit_status):
            dlg.close()
            for btn in getattr(self, "_action_buttons", []):
                btn.setEnabled(True)

            ok = (exit_code == 0 and exit_status == QProcess.NormalExit)
            if ok:
                log_run_footer_ok(context)
                if on_success:
                    on_success()
            else:
                out_text = self._last_stdout.decode(errors="ignore")
                err_text = self._last_stderr.decode(errors="ignore")
                log_run_footer_fail(context, exit_code, out_text, err_text)
                if on_fail:
                    on_fail(out_text, err_text)

            proc.deleteLater()

        proc.finished.connect(_finish)

        def _cancel():
            if proc.state() != QProcess.NotRunning:
                LOGGER.warning("[CANCEL] %s richiesto dall'utente", context)
                proc.kill()

        dlg.canceled.connect(_cancel)
        proc.start()

    def __init__(self):
        super().__init__()
        scroll = QScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOn)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        content = QWidget()
        content.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Maximum)

        layout = QGridLayout(content)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setHorizontalSpacing(6)
        layout.setVerticalSpacing(4)

        row = 0
        self.reads_entry = self._add_path_row(layout, "FASTQ Folder", row, folder=True); row += 1
        self.outdir_entry = self._add_path_row(layout, "Output Folder", row, folder=True); row += 1
        self.db_entry = self._add_path_row(layout, "Database Folder", row, folder=True); row += 1
        self.db_entry.setText(default_database_path())

        layout.addWidget(QLabel("Primers (FWD;REV)"), row, 0)
        self.primers_entry = QLineEdit("AGAGTTTGATCCTGGCTCAG;TGCTGCCTCCCGTAGGAGT")
        layout.addWidget(self.primers_entry, row, 1); row += 1

        layout.addWidget(QLabel("Previously run (TRUE/FALSE)"), row, 0)
        self.prev_entry = QLineEdit("FALSE")
        layout.addWidget(self.prev_entry, row, 1); row += 1

        layout.addWidget(QLabel("CPU cores"), row, 0)
        self.ncores_entry = QSpinBox()
        self.ncores_entry.setRange(1, max(1, os.cpu_count() or 1))
        self.ncores_entry.setValue(default_ncores())
        layout.addWidget(self.ncores_entry, row, 1); row += 1

        self.btn_qc = QPushButton("Run QC (generate plots)")
        self.btn_qc.clicked.connect(self.run_qc)
        layout.addWidget(self.btn_qc, row, 0, 1, 2); row += 1

        layout.addWidget(QLabel("TrimF"), row, 0)
        self.trimF_entry = QLineEdit()
        self.trimF_entry.setText("230")   # default
        layout.addWidget(self.trimF_entry, row, 1); row += 1

        layout.addWidget(QLabel("TrimR"), row, 0)
        self.trimR_entry = QLineEdit()
        self.trimR_entry.setText("220")   # default
        layout.addWidget(self.trimR_entry, row, 1); row += 1

        self.btn_full = QPushButton("Run Full Pipeline")
        self.btn_full.clicked.connect(self.run_full)
        layout.addWidget(self.btn_full, row, 0, 1, 2); row += 1

        # lingua + istruzioni
        self.lang_toggle = QComboBox()
        self.lang_toggle.addItems(["English", "Italiano"])
        layout.addWidget(self.lang_toggle, row, 0, 1, 1)

        self.btn_instr = QPushButton("Instructions")
        self.btn_instr.clicked.connect(self.show_instructions)
        layout.addWidget(self.btn_instr, row, 1, 1, 1); row += 1

        # registra i bottoni di azione
        self._action_buttons = [self.btn_qc, self.btn_full, self.btn_instr]

        scroll.setWidget(content)

        logo_pix = QPixmap(resource_path("assets/logo.png"))
        logo_pix = logo_pix.scaledToWidth(150, Qt.SmoothTransformation)
        logo_label = QLabel()
        logo_label.setPixmap(logo_pix)
        logo_label.setAlignment(Qt.AlignCenter)

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)
        main_layout.addStretch()
        main_layout.addWidget(logo_label)
        self.setLayout(main_layout)

    def show_instructions(self):
        lang = self.lang_toggle.currentText()

        instructions_en = textwrap.dedent("""\
            📘 Instructions

            === Pipeline Tab ===
            1. Select the folder containing the FASTQ files.
            2. Choose the output folder where results will be saved.
            3. Enter primer sequences as: FWD;REV.
            4. Specify whether there is a previous run (TRUE/FALSE).
            5. Set CPU cores. Use a low value on laptops.
            6. Click "Run QC" to perform the first step of the analysis.
            7. At the end of QC, the quality plots open automatically. They are also saved under
               "04_plots" in the chosen output folder as "quality_forward.pdf" and "quality_reverse.pdf".
               Use them to decide the trimming lengths.
            8. Enter TrimF and TrimR (defaults are 230 and 220).
            9. Click "Run Full Pipeline" to execute the full workflow (QC, filtering, merging,
               chimera removal, taxonomy).

            === Anamnesis Tab ===
            1. Fill in metadata:
               * Sample code (must match the FASTQ file name), name, surname, sex, date of birth.
               * Lifestyle/health info (antibiotics, supplements, digestive health, etc.).
               * Any symptoms or recent test results.
            2. Save to a folder.
            3. Repeat for each sample before generating the report.
            4. If some information is not provided, select "Not provided" where available,
               or choose "No".

            === Report Tab ===
            1. Select the file "Species_merged_count.txt" located in "06_tables_silva" produced by the pipeline.
            2. Choose the output folder.
            3. Select the folder containing the anamnesis files.
            4. Click "Generate demo report" to generate results in the selected folder.

            Reports include:
            * Taxonomic composition (phylum/genus).
            * Genus-level rarefaction and selected sample metadata.
            * Three arbitrary demo mappings without biological functional meaning.
            * No health classification or personalized advice in this portfolio preview.
        """)

        instructions_it = textwrap.dedent("""\
            📘 Istruzioni

            === Tab Pipeline ===
            1. Seleziona la cartella con i file FASTQ.
            2. Scegli la cartella di output dove salvare i risultati.
            3. Inserisci i primer nel formato: FWD;REV.
            4. Specifica se esiste un'analisi precedente (TRUE/FALSE).
            5. Imposta i core CPU. Usa un valore basso sui portatili.
            6. Premi Run QC per eseguire il primo step dell’analisi.
            7. Controlla i grafici che si aprono automaticamente alla fine dello step per decidere i valori di trimming.
               I grafici sono salvati nella cartella "04_plots" che si trova nell'output indicato con il nome
               "quality_forward.pdf" e "quality_reverse.pdf".
            8. Inserisci i valori di trimming.
            9. Clicca "Run Full Pipeline" per eseguire il workflow (QC, filtraggio, merging, rimozione chimere, tassonomia).

            === Tab Anamnesi ===
            1. Compila i metadati:
               * Codice campione (deve corrispondere al nome del file FASTQ), nome, cognome, sesso, data di nascita.
               * Informazioni su stile di vita e salute (antibiotici, integratori, digestione, ecc.).
               * Eventuali sintomi o risultati di esami.
            2. Salva in una cartella.
            3. Ripeti per ogni campione prima di passare al report.
            4. Se l'informazione non è fornita selezionare ove possibile "Non fornito" o scegliere l'opzione "No"

            === Tab Report ===
            1. Seleziona il file "Species_merged_count.txt" che si trova nella cartella "06_tables_silva" prodotto dalla pipeline.
            2. Scegli una cartella di output.
            3. Seleziona la cartella contenente i file di anamnesi.
            4. Clicca "Genera report demo" per generare i risultati nella cartella selezionata.

            I report includono:
            * Composizione tassonomica (phylum/genere).
            * Rarefazione a livello di genere e metadati selezionati del campione.
            * Tre associazioni demo arbitrarie senza significato funzionale biologico.
            * Nessuna classificazione sanitaria o consiglio personalizzato in questa anteprima.
        """)

        instructions = instructions_it if lang == "Italiano" else instructions_en

        dlg = QDialog(self)
        dlg.setWindowTitle("Istruzioni" if lang == "Italiano" else "Instructions")
        dlg.resize(600, 500)

        v = QVBoxLayout(dlg)
        text = QTextEdit()
        text.setReadOnly(True)
        text.setText(instructions)
        v.addWidget(text)

        btn_close = QPushButton("Chiudi" if lang == "Italiano" else "Close")
        btn_close.clicked.connect(dlg.close)
        v.addWidget(btn_close, alignment=Qt.AlignRight)

        dlg.exec_()

    # ===== Utility =====
    def _add_path_row(self, layout, label, row, folder=False, filter_str="Tutti i file (*.*)"):
        layout.addWidget(QLabel(label), row, 0)
        entry = QLineEdit()
        layout.addWidget(entry, row, 1)
        btn = QPushButton("Browse")
        if folder:
            btn.clicked.connect(lambda: browse_folder(entry))
        else:
            btn.clicked.connect(lambda: browse_file(entry, filter_str))
        layout.addWidget(btn, row, 2)
        return entry

    # ===== Esecuzioni =====
    def run_qc(self):
        reads = self.reads_entry.text().strip()
        outdir = self.outdir_entry.text().strip()
        dbdir = self.db_entry.text().strip()
        ncores = str(self.ncores_entry.value())
        primers = self.primers_entry.text().strip()
        prev = self.prev_entry.text().strip()

        if not (reads and outdir and dbdir):
            QMessageBox.critical(self, "Errore", "Seleziona FASTQ folder, output folder e database folder.")
            return

        os.makedirs(outdir, exist_ok=True)

        r_script = resource_path("R/dada2_analysis.R")
        r_exe = shutil.which("Rscript")
        if not r_exe:
            QMessageBox.critical(self, "Errore", "Rscript non trovato nel PATH.")
            return

        cmd = [
            r_exe, r_script,
            "--readsdir", reads,
            "--basedir", outdir,
            "--DBdir", dbdir,
            "--primers", primers,
            "--previously_run", prev,
            "--ncores", ncores,
            "--step", "qc"
        ]

        def on_success():
            QMessageBox.information(self, "OK", "QC completato con successo!")
            plots_dir = os.path.join(outdir, "04_plots")
            for name in ("quality_forward.pdf", "quality_reverse.pdf"):
                pdf = os.path.join(plots_dir, name)
                if os.path.exists(pdf):
                    QDesktopServices.openUrl(QUrl.fromLocalFile(pdf))

        def on_fail(stdout, stderr):
            ret = QMessageBox.critical(
                self, "QC fallito",
                f"Si è verificato un errore durante il QC.\nVuoi aprire il file di log?\n{get_log_path()}",
                QMessageBox.Yes | QMessageBox.No
            )
            if ret == QMessageBox.Yes:
                QDesktopServices.openUrl(QUrl.fromLocalFile(get_log_path()))

        self.run_process_async(
            cmd,
            on_success=on_success,
            on_fail=on_fail,
            cwd=os.path.dirname(r_script),
            title="QC",
            label_text="Esecuzione QC in corso…",
            context="QC"
        )

    def run_full(self):
        reads = self.reads_entry.text().strip()
        outdir = self.outdir_entry.text().strip()
        dbdir = self.db_entry.text().strip()
        ncores = str(self.ncores_entry.value())
        primers = self.primers_entry.text().strip()
        prev = self.prev_entry.text().strip()
        trimF = self.trimF_entry.text().strip()
        trimR = self.trimR_entry.text().strip()

        if not (reads and outdir and dbdir and trimF and trimR):
            QMessageBox.critical(self, "Errore", "Compila tutti i parametri richiesti (database folder, TrimF, TrimR).")
            return

        os.makedirs(outdir, exist_ok=True)

        r_script = resource_path("R/dada2_analysis.R")
        r_exe = shutil.which("Rscript")
        if not r_exe:
            QMessageBox.critical(self, "Errore", "Rscript non trovato nel PATH.")
            return

        cmd = [
            r_exe, r_script,
            "--readsdir", reads,
            "--basedir", outdir,
            "--DBdir", dbdir,
            "--primers", primers,
            "--previously_run", prev,
            "--step", "full",
            "--trimF", trimF,
            "--trimR", trimR,
            "--ncores", ncores
        ]

        def on_success():
            QMessageBox.information(self, "OK", "Pipeline completata con successo!")

        def on_fail(stdout, stderr):
            ret = QMessageBox.critical(
                self, "Pipeline fallita",
                f"Il processo si è concluso con un errore.\nVuoi aprire il file di log?\n{get_log_path()}",
                QMessageBox.Yes | QMessageBox.No
            )
            if ret == QMessageBox.Yes:
                QDesktopServices.openUrl(QUrl.fromLocalFile(get_log_path()))

        self.run_process_async(
            cmd,
            on_success=on_success,
            on_fail=on_fail,
            cwd=os.path.dirname(r_script),
            title="Pipeline",
            label_text="Esecuzione pipeline completa in corso…",
            context="FULL_PIPELINE"
        )


# ========= TAB ANAMNESI COMPLETA =========
class AnamnesiTab(QWidget):
    LABELS_EN = {
        "Lingua": "Language",
        "Codice campione *": "Sample code *",
        "Nome": "Name",
        "Cognome": "Surname",
        "Sesso": "Sex",
        "Data di nascita": "Date of birth",
        "Codice fiscale": "Tax code",
        "Indirizzo": "Address",
        "Tipologia di report": "Report type",
        "Professionista di riferimento": "Reference professional",
        "Età": "Age",
        "Peso (kg)": "Weight (kg)",
        "Altezza (cm)": "Height (cm)",
        "Regolarità intestinale": "Bowel regularity",
        "Frequenza di evacuazione intestinale": "Bowel movement frequency",
        "Scala di Bristol": "Bristol Stool Scale",
        "Uso di antibiotici (ultimi 6 mesi)": "Antibiotic use (last 6 months)",
        "Se sì, quali antibiotici": "If yes, which antibiotics",
        "Uso di integratori (ultimi 6 mesi)": "Supplement use (last 6 months)",
        "Se sì, quali integratori": "If yes, which supplements",
        "Reflusso": "Reflux",
        "Gonfiore": "Bloating",
        "Dispepsia": "Dyspepsia",
        "Meteorismo": "Flatulence",
        "Emorroidi": "Hemorrhoids",
        "Stile alimentare": "Dietary pattern",
        "Uso di fitoestrogeni": "Phytoestrogen use",
        "Patologie (ultimi 5 anni)": "Diseases (last 5 years)",
        "Cure farmacologiche (ultimi 5 anni)": "Drug therapies (last 5 years)",
        "Attività fisica (frequenza)": "Physical activity (frequency)",
        "Fumatore": "Smoker",
        "Qualità del sonno": "Sleep quality",
        "Tipo di parto": "Birth mode",
        "Allattamento (≥ 6 mesi)?": "Breastfeeding (>= 6 months)?",
        "Specificare il periodo (allattamento)": "Specify breastfeeding period",
        "Consumo di alcool": "Alcohol consumption",
        "Frequenza alcool (settimanale)": "Alcohol frequency (weekly)",
        "Uso di sostanze": "Substance use",
        "Se sì, quali sostanze": "If yes, which substances",
        "Condizioni fisiologiche particolari": "Special physiological conditions",
        "Allergie o intolleranze": "Allergies or intolerances",
        "Altri sintomi da riferire": "Other symptoms to report",
        "Valori alterati esami (≤6 mesi)": "Altered test values (<=6 months)",
        "Consenso privacy": "Privacy consent",
    }

    OPTION_LABELS_EN = {
        "Sì": "Yes",
        "No": "No",
        "Regolare": "Regular",
        "Stipsi": "Constipation",
        "Diarroico": "Diarrhea",
        "Alternato": "Alternating",
        "Normale": "Normal",
        "Completo": "Complete",
        "Intermedio": "Intermediate",
        "Base": "Basic",
        "Naturale": "Natural",
        "Artificiale": "Formula",
        "Misto": "Mixed",
        "Non fornito": "Not provided",
        "Accetto": "Accepted",
        "Non accetto": "Not accepted",
    }

    def __init__(self):
        super().__init__()
        self.lang = "Italiano"
        self._translated_labels = []
        self._translated_combos = []

        scroll = QScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOn)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        content = QWidget()
        content.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Maximum)

        layout = QGridLayout(content)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setHorizontalSpacing(6)
        layout.setVerticalSpacing(4)
        row = 0

        self.lang_label = self._add_label(layout, "Lingua", row)
        self.lang_toggle = QComboBox()
        self.lang_toggle.addItems(["English", "Italiano"])
        self.lang_toggle.setCurrentText(self.lang)
        self.lang_toggle.currentTextChanged.connect(self.set_language)
        layout.addWidget(self.lang_toggle, row, 1)
        row += 1

        # --- Anagrafica / identificazione campione ---
        self.codice = self._add_line(layout, "Codice campione *", row); row += 1
        self.nome = self._add_line(layout, "Nome", row); row += 1
        self.cognome = self._add_line(layout, "Cognome", row); row += 1
        self.sesso = self._add_combo(layout, "Sesso", ["M", "F"], row); row += 1

        self.data_nascita_label = self._add_label(layout, "Data di nascita", row)
        self.data_nascita = QDateEdit()
        self.data_nascita.setDisplayFormat("dd/MM/yyyy")
        self.data_nascita.setCalendarPopup(True)
        self.data_nascita.setDate(QDate.currentDate())
        layout.addWidget(self.data_nascita, row, 1); row += 1

        self.codice_fiscale = self._add_line(layout, "Codice fiscale", row); row += 1
        self.indirizzo = self._add_line(layout, "Indirizzo", row); row += 1
        self.tipologia_report = self._add_combo(layout, "Tipologia di report", ["Demo"], row); row += 1
        self.professionista = self._add_line(layout, "Professionista di riferimento", row); row += 1

        self.eta_label = self._add_label(layout, "Età", row)
        self.eta = QSpinBox(); self.eta.setRange(0, 120)
        layout.addWidget(self.eta, row, 1); row += 1

        self.peso_label = self._add_label(layout, "Peso (kg)", row)
        self.peso = QDoubleSpinBox(); self.peso.setRange(0, 500); self.peso.setDecimals(2)
        layout.addWidget(self.peso, row, 1); row += 1

        self.altezza_label = self._add_label(layout, "Altezza (cm)", row)
        self.altezza = QDoubleSpinBox(); self.altezza.setRange(0, 300); self.altezza.setDecimals(1)
        layout.addWidget(self.altezza, row, 1); row += 1

        # --- Intestino / scala Bristol ---
        self.intestino = self._add_combo(layout, "Regolarità intestinale", ["Regolare","Stipsi","Diarroico","Alternato","Normale"], row); row += 1
        self.intestino_frequenza = self._add_line(layout, "Frequenza di evacuazione intestinale", row); row += 1
        self.scala_bristol = self._add_combo(layout, "Scala di Bristol", [str(i) for i in range(1, 8)], row); row += 1

        pixmap = QPixmap(resource_path("assets/bristol.png"))
        if not pixmap.isNull():
            img_label = QLabel()
            img_label.setPixmap(pixmap.scaledToWidth(420, Qt.SmoothTransformation))
            layout.addWidget(img_label, row, 0, 1, 2)
            row += 1

        # --- Farmaci, abitudini, sintomi, ecc. ---
        self.antibiotici = self._add_combo(layout, "Uso di antibiotici (ultimi 6 mesi)", ["Sì","No"], row); row += 1
        self.lista_antibiotici = self._add_line(layout, "Se sì, quali antibiotici", row); row += 1

        self.integratori = self._add_combo(layout, "Uso di integratori (ultimi 6 mesi)", ["Sì","No"], row); row += 1
        self.lista_integratori = self._add_line(layout, "Se sì, quali integratori", row); row += 1

        self.reflusso = self._add_combo(layout, "Reflusso", ["Sì","No"], row); row += 1
        self.gonfiore = self._add_combo(layout, "Gonfiore", ["Sì","No"], row); row += 1
        self.dispepsia = self._add_combo(layout, "Dispepsia", ["Sì","No"], row); row += 1
        self.meteorismo = self._add_combo(layout, "Meteorismo", ["Sì","No"], row); row += 1
        self.emorroidi = self._add_combo(layout, "Emorroidi", ["Sì","No"], row); row += 1

        self.alimentazione = self._add_line(layout, "Stile alimentare", row); row += 1
        self.fitoestrogeni = self._add_combo(layout, "Uso di fitoestrogeni", ["Sì","No"], row); row += 1

        self.patologie = self._add_line(layout, "Patologie (ultimi 5 anni)", row); row += 1
        self.farmaci = self._add_line(layout, "Cure farmacologiche (ultimi 5 anni)", row); row += 1
        self.sport = self._add_line(layout, "Attività fisica (frequenza)", row); row += 1
        self.fumatore = self._add_combo(layout, "Fumatore", ["Sì","No"], row); row += 1
        self.sonno = self._add_line(layout, "Qualità del sonno", row); row += 1
        self.parto = self._add_line(layout, "Tipo di parto", row); row += 1

        self.allattamento = self._add_combo(layout, "Allattamento (≥ 6 mesi)?", ["Naturale","Artificiale","Misto","Non fornito"], row); row += 1
        self.periodo_allattamento = self._add_line(layout, "Specificare il periodo (allattamento)", row); row += 1

        self.alcool = self._add_combo(layout, "Consumo di alcool", ["Sì","No"], row); row += 1
        self.periodo_alcool = self._add_line(layout, "Frequenza alcool (settimanale)", row); row += 1

        self.droghe = self._add_combo(layout, "Uso di sostanze", ["Sì","No"], row); row += 1
        self.periodo_droga = self._add_line(layout, "Se sì, quali sostanze", row); row += 1

        self.fisiologia = self._add_line(layout, "Condizioni fisiologiche particolari", row); row += 1
        self.allergie = self._add_line(layout, "Allergie o intolleranze", row); row += 1

        self.sintomi = self._add_text(layout, "Altri sintomi da riferire", row); row += 1
        self.esami = self._add_text(layout, "Valori alterati esami (≤6 mesi)", row); row += 1

        self.privacy = self._add_combo(layout, "Consenso privacy", ["Accetto","Non accetto"], row); row += 1

        # --- Pulsanti Salva/Carica JSON ---
        self.btn_load = QPushButton("Carica JSON")
        self.btn_load.clicked.connect(self.load_json)

        self.btn_save = QPushButton("Salva JSON")
        self.btn_save.clicked.connect(self.save_json)

        layout.addWidget(self.btn_load, row, 0)
        layout.addWidget(self.btn_save, row, 1)
        row += 1

        # Scroll wrapper
        scroll.setWidget(content)
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)
        self.setLayout(main_layout)
        self.set_language(self.lang)

    # ---- Helper UI ----
    def _translate_label(self, text: str) -> str:
        return self.LABELS_EN.get(text, text) if self.lang == "English" else text

    def _translate_option(self, text: str) -> str:
        return self.OPTION_LABELS_EN.get(text, text) if self.lang == "English" else text

    def _add_label(self, layout, label, row):
        label_widget = QLabel(label)
        label_widget._canonical_text = label
        self._translated_labels.append(label_widget)
        layout.addWidget(label_widget, row, 0)
        return label_widget

    def _add_line(self, layout, label, row):
        self._add_label(layout, label, row)
        w = QLineEdit()
        layout.addWidget(w, row, 1)
        return w

    def _add_combo(self, layout, label, options, row):
        self._add_label(layout, label, row)
        combo = QComboBox()
        combo._canonical_options = list(options)
        for option in options:
            combo.addItem(option, option)
        self._translated_combos.append(combo)
        if "No" in options:
            combo.setCurrentIndex(combo.findData("No"))
        else:
            combo.setCurrentIndex(-1)
        layout.addWidget(combo, row, 1)
        return combo

    def _add_text(self, layout, label, row):
        self._add_label(layout, label, row)
        t = QTextEdit()
        layout.addWidget(t, row, 1)
        return t

    def set_language(self, lang: str):
        if lang not in ("English", "Italiano"):
            return
        self.lang = lang
        if self.lang_toggle.currentText() != lang:
            self.lang_toggle.blockSignals(True)
            self.lang_toggle.setCurrentText(lang)
            self.lang_toggle.blockSignals(False)

        for label in self._translated_labels:
            label.setText(self._translate_label(label._canonical_text))

        for combo in self._translated_combos:
            current = combo.currentData()
            combo.blockSignals(True)
            combo.clear()
            for option in combo._canonical_options:
                combo.addItem(self._translate_option(option), option)
            if current:
                combo.setCurrentIndex(combo.findData(current))
            elif "No" in combo._canonical_options:
                combo.setCurrentIndex(combo.findData("No"))
            else:
                combo.setCurrentIndex(-1)
            combo.blockSignals(False)

        self.btn_load.setText("Load JSON" if lang == "English" else "Carica JSON")
        self.btn_save.setText("Save JSON" if lang == "English" else "Salva JSON")

    def _combo_value(self, combo: QComboBox) -> str:
        data = combo.currentData()
        return data if data is not None else combo.currentText()

    # ---- Serializzazione ----
    def _to_dict(self) -> dict:
        def qdate_to_iso(qd: QDate) -> str:
            return f"{qd.year():04d}-{qd.month():02d}-{qd.day():02d}"

        return {
            "codice": self.codice.text().strip(),
            "nome": self.nome.text().strip(),
            "cognome": self.cognome.text().strip(),
            "sesso": self._combo_value(self.sesso),
            "data_nascita": qdate_to_iso(self.data_nascita.date()),
            "codice_fiscale": self.codice_fiscale.text().strip(),
            "indirizzo": self.indirizzo.text().strip(),
            "tipologia_report": self._combo_value(self.tipologia_report),
            "professionista": self.professionista.text().strip(),
            "eta": self.eta.value(),
            "peso": float(self.peso.value()),
            "altezza": float(self.altezza.value()),
            "intestino": self._combo_value(self.intestino),
            "intestino_frequenza": self.intestino_frequenza.text().strip(),
            "scala_bristol": self._combo_value(self.scala_bristol),
            "antibiotici": self._combo_value(self.antibiotici),
            "lista_antibiotici": self.lista_antibiotici.text().strip(),
            "integratori": self._combo_value(self.integratori),
            "lista_integratori": self.lista_integratori.text().strip(),
            "reflusso": self._combo_value(self.reflusso),
            "gonfiore": self._combo_value(self.gonfiore),
            "dispepsia": self._combo_value(self.dispepsia),
            "meteorismo": self._combo_value(self.meteorismo),
            "emorroidi": self._combo_value(self.emorroidi),
            "alimentazione": self.alimentazione.text().strip(),
            "fitoestrogeni": self._combo_value(self.fitoestrogeni),
            "patologie": self.patologie.text().strip(),
            "farmaci": self.farmaci.text().strip(),
            "sport": self.sport.text().strip(),
            "fumatore": self._combo_value(self.fumatore),
            "sonno": self.sonno.text().strip(),
            "parto": self.parto.text().strip(),
            "allattamento": self._combo_value(self.allattamento),
            "periodo_allattamento": self.periodo_allattamento.text().strip(),
            "alcool": self._combo_value(self.alcool),
            "periodo_alcool": self.periodo_alcool.text().strip(),
            "droghe": self._combo_value(self.droghe),
            "periodo_droga": self.periodo_droga.text().strip(),
            "fisiologia": self.fisiologia.text().strip(),
            "allergie": self.allergie.text().strip(),
            "sintomi": self.sintomi.toPlainText().strip(),
            "esami": self.esami.toPlainText().strip(),
            "privacy": self._combo_value(self.privacy),
        }

    def _apply_dict(self, d: dict):
        def set_combo(combo: QComboBox, value: str):
            idx = combo.findData(value)
            if idx < 0:
                idx = combo.findText(value)
            if idx >= 0:
                combo.setCurrentIndex(idx)

        self.codice.setText(d.get("codice",""))
        self.nome.setText(d.get("nome",""))
        self.cognome.setText(d.get("cognome",""))
        set_combo(self.sesso, d.get("sesso",""))
        try:
            y,m,dn = (int(x) for x in d.get("data_nascita","").split("-"))
            self.data_nascita.setDate(QDate(y,m,dn))
        except Exception:
            pass
        self.codice_fiscale.setText(d.get("codice_fiscale",""))
        self.indirizzo.setText(d.get("indirizzo",""))
        set_combo(self.tipologia_report, d.get("tipologia_report",""))
        self.professionista.setText(d.get("professionista",""))
        if "eta" in d: self.eta.setValue(int(d["eta"]))
        if "peso" in d: self.peso.setValue(float(d["peso"]))
        if "altezza" in d: self.altezza.setValue(float(d["altezza"]))
        set_combo(self.intestino, d.get("intestino",""))
        self.intestino_frequenza.setText(d.get("intestino_frequenza",""))
        set_combo(self.scala_bristol, d.get("scala_bristol",""))
        set_combo(self.antibiotici, d.get("antibiotici",""))
        self.lista_antibiotici.setText(d.get("lista_antibiotici",""))
        set_combo(self.integratori, d.get("integratori",""))
        self.lista_integratori.setText(d.get("lista_integratori",""))
        set_combo(self.reflusso, d.get("reflusso",""))
        set_combo(self.gonfiore, d.get("gonfiore",""))
        set_combo(self.dispepsia, d.get("dispepsia",""))
        set_combo(self.meteorismo, d.get("meteorismo",""))
        set_combo(self.emorroidi, d.get("emorroidi",""))
        self.alimentazione.setText(d.get("alimentazione",""))
        set_combo(self.fitoestrogeni, d.get("fitoestrogeni",""))
        self.patologie.setText(d.get("patologie",""))
        self.farmaci.setText(d.get("farmaci",""))
        self.sport.setText(d.get("sport",""))
        set_combo(self.fumatore, d.get("fumatore",""))
        self.sonno.setText(d.get("sonno",""))
        self.parto.setText(d.get("parto",""))
        set_combo(self.allattamento, d.get("allattamento",""))
        self.periodo_allattamento.setText(d.get("periodo_allattamento",""))
        set_combo(self.alcool, d.get("alcool",""))
        self.periodo_alcool.setText(d.get("periodo_alcool",""))
        set_combo(self.droghe, d.get("droghe",""))
        self.periodo_droga.setText(d.get("periodo_droga",""))
        self.fisiologia.setText(d.get("fisiologia",""))
        self.allergie.setText(d.get("allergie",""))
        self.sintomi.setPlainText(d.get("sintomi",""))
        self.esami.setPlainText(d.get("esami",""))
        set_combo(self.privacy, d.get("privacy",""))

    # ---- Azioni ----
    def save_json(self):
        data = self._to_dict()

        # Avviso se privacy non accettata
        if data.get("privacy") != "Accetto":
            privacy_title = "Privacy consent" if self.lang == "English" else "Consenso privacy"
            privacy_message = (
                "Privacy consent is not set to 'Accepted'.\n"
                "Do you want to save the JSON file anyway?"
                if self.lang == "English"
                else
                "Il consenso privacy non è impostato su 'Accetto'.\n"
                "Vuoi salvare comunque il file JSON?"
            )
            ret = QMessageBox.warning(
                self, privacy_title, privacy_message,
                QMessageBox.Yes | QMessageBox.No
            )
            if ret != QMessageBox.Yes:
                return

        if not data.get("codice"):
            title = "Error" if self.lang == "English" else "Errore"
            message = "The 'Sample code' field is required." if self.lang == "English" else "Il campo 'Codice campione' è obbligatorio."
            QMessageBox.critical(self, title, message)
            return

        suggested = f"{data['codice']}_anamnesi.json"
        dialog_title = "Save anamnesis as JSON" if self.lang == "English" else "Salva anamnesi in JSON"
        path, _ = QFileDialog.getSaveFileName(self, dialog_title, suggested, "JSON (*.json)")
        if not path:
            return

        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            saved = "File saved" if self.lang == "English" else "File salvato"
            QMessageBox.information(self, "OK", f"{saved}:\n{path}")
        except Exception as e:
            title = "Save error" if self.lang == "English" else "Errore salvataggio"
            QMessageBox.critical(self, title, str(e))

    def load_json(self):
        dialog_title = "Load anamnesis from JSON" if self.lang == "English" else "Carica anamnesi da JSON"
        path, _ = QFileDialog.getOpenFileName(self, dialog_title, "", "JSON (*.json)")
        if not path:
            return
        try:
            with open(path, "r", encoding="utf-8") as f:
                d = json.load(f)
            self._apply_dict(d)
            loaded = "Data loaded from" if self.lang == "English" else "Dati caricati da"
            QMessageBox.information(self, "OK", f"{loaded}:\n{path}")
        except Exception as e:
            title = "Read error" if self.lang == "English" else "Errore lettura"
            QMessageBox.critical(self, title, str(e))



# ========= TAB REPORT =========
class ReportTab(QWidget):
    LABELS = {
        "English": {
            "Input abundance table": "Input abundance table",
            "Output folder": "Output folder",
            "Anamnesi folder": "Anamnesis folder",
            "Language": "Language",
            "Run Report": "Generate demo report",
            "Portfolio preview": "Portfolio preview: descriptive report and synthetic mappings; no personalized advice.",
            "Browse": "Browse",
            "Select all required inputs.": "Select input, output folder and anamnesis folder.",
            "Rscript not found in PATH.": "Rscript not found in PATH.",
            "Report generated successfully!": "Report generated successfully!",
            "Report generation failed": "Report generation failed",
            "An error occurred.": "An error occurred.",
            "Do you want to open the log file?": "Do you want to open the log file?",
            "Generating report...": "Generating report...",
        },
        "Italiano": {
            "Input abundance table": "Tabella abbondanze input",
            "Output folder": "Cartella output",
            "Anamnesi folder": "Cartella anamnesi",
            "Language": "Lingua",
            "Run Report": "Genera report demo",
            "Portfolio preview": "Anteprima portfolio: report descrittivo e associazioni sintetiche; nessun consiglio personalizzato.",
            "Browse": "Sfoglia",
            "Select all required inputs.": "Seleziona input, output e la cartella con i file di anamnesi.",
            "Rscript not found in PATH.": "Rscript non trovato nel PATH.",
            "Report generated successfully!": "Report generato con successo!",
            "Report generation failed": "Generazione report fallita",
            "An error occurred.": "Si è verificato un errore.",
            "Do you want to open the log file?": "Vuoi aprire il file di log?",
            "Generating report...": "Generazione report in corso...",
        },
    }

    def __init__(self):
        super().__init__()
        self.lang = "English"
        self._labels = []
        self._browse_buttons = []
        layout = QGridLayout()
        row = 0

        self.input_entry = self._add_path_row(layout, "Input abundance table", row, folder=False,
                                              filter_str="Testo (*.txt);;Tutti i file (*.*)"); row += 1
        self.outdir_entry = self._add_path_row(layout, "Output folder", row, folder=True); row += 1
        self.anamnesis_entry = self._add_path_row(layout, "Anamnesi folder", row, folder=True); row += 1

        self.language_label = self._add_label(layout, "Language", row)
        self.lang_toggle = QComboBox()
        self.lang_toggle.addItems(["English", "Italiano"])
        self.lang_toggle.currentTextChanged.connect(self.set_language)
        layout.addWidget(self.lang_toggle, row, 1, 1, 2); row += 1

        self.preview_label = QLabel()
        self.preview_label.setWordWrap(True)
        layout.addWidget(self.preview_label, row, 0, 1, 3); row += 1

        self.btn_run = QPushButton("Run Report")
        self.btn_run.clicked.connect(self.run_report)
        layout.addWidget(self.btn_run, row, 0, 1, 3); row += 1

        self.setLayout(layout)
        self.set_language(self.lang)

        # registra i bottoni da disabilitare durante l'esecuzione
        self._action_buttons = [self.btn_run]

    def tr(self, text: str) -> str:
        return self.LABELS.get(self.lang, self.LABELS["English"]).get(text, text)

    def set_language(self, lang: str):
        if lang not in ("English", "Italiano"):
            return
        self.lang = lang
        if self.lang_toggle.currentText() != lang:
            self.lang_toggle.blockSignals(True)
            self.lang_toggle.setCurrentText(lang)
            self.lang_toggle.blockSignals(False)
        for label in self._labels:
            label.setText(self.tr(label._canonical_text))
        for btn in self._browse_buttons:
            btn.setText(self.tr("Browse"))
        self.btn_run.setText(self.tr("Run Report"))
        self.preview_label.setText(self.tr("Portfolio preview"))

    def _add_label(self, layout, label, row):
        label_widget = QLabel(label)
        label_widget._canonical_text = label
        self._labels.append(label_widget)
        layout.addWidget(label_widget, row, 0)
        return label_widget

    def _add_path_row(self, layout, label, row, folder=False, filter_str="Tutti i file (*.*)"):
        self._add_label(layout, label, row)
        entry = QLineEdit()
        layout.addWidget(entry, row, 1)
        btn = QPushButton("Browse")
        self._browse_buttons.append(btn)
        if folder:
            btn.clicked.connect(lambda: browse_folder(entry))
        else:
            btn.clicked.connect(lambda: browse_file(entry, filter_str))
        layout.addWidget(btn, row, 2)
        return entry

    # ---- runner asincrono con progress dialog e logging ----
    def _run_process_async(self, cmd, cwd=None, title="Report", label_text="Generazione report in corso…"):
        # Disabilita i bottoni
        for b in getattr(self, "_action_buttons", []):
            b.setEnabled(False)

        dlg = QProgressDialog(label_text, "Cancel", 0, 0, self)
        dlg.setWindowTitle(title)
        dlg.setWindowModality(Qt.WindowModal)
        dlg.setAutoClose(False)
        dlg.setAutoReset(False)
        dlg.setMinimumDuration(0)
        dlg.show()

        proc = QProcess(self)
        if cwd:
            proc.setWorkingDirectory(cwd)

        program, *args = cmd
        proc.setProgram(program)
        proc.setArguments(args)

        # buffer e header log
        self._last_stdout = b""
        self._last_stderr = b""
        log_run_header("REPORT", [program] + args, cwd)

        def _read_out():
            chunk = proc.readAllStandardOutput().data()
            if chunk:
                self._last_stdout += chunk
                try:
                    LOGGER.debug("[STDOUT][REPORT] %s", chunk.decode(errors="ignore").rstrip())
                except Exception:
                    pass

        def _read_err():
            chunk = proc.readAllStandardError().data()
            if chunk:
                self._last_stderr += chunk
                try:
                    LOGGER.debug("[STDERR][REPORT] %s", chunk.decode(errors="ignore").rstrip())
                except Exception:
                    pass

        proc.readyReadStandardOutput.connect(_read_out)
        proc.readyReadStandardError.connect(_read_err)

        def _finish(exit_code, exit_status):
            dlg.close()
            for b in getattr(self, "_action_buttons", []):
                b.setEnabled(True)

            ok = (exit_code == 0 and exit_status == QProcess.NormalExit)
            if ok:
                log_run_footer_ok("REPORT")
                QMessageBox.information(self, "OK", f"{self.tr('Report generated successfully!')}\n\nLog: {get_log_path()}")
            else:
                out_text = self._last_stdout.decode(errors="ignore")
                err_text = self._last_stderr.decode(errors="ignore")
                log_run_footer_fail("REPORT", exit_code, out_text, err_text)

                ret = QMessageBox.critical(
                    self, self.tr("Report generation failed"),
                    f"{self.tr('An error occurred.')}\n{self.tr('Do you want to open the log file?')}\n{get_log_path()}",
                    QMessageBox.Yes | QMessageBox.No
                )
                if ret == QMessageBox.Yes:
                    QDesktopServices.openUrl(QUrl.fromLocalFile(get_log_path()))

            proc.deleteLater()

        proc.finished.connect(_finish)

        def _cancel():
            if proc.state() != QProcess.NotRunning:
                LOGGER.warning("[CANCEL] REPORT richiesto dall'utente")
                proc.kill()

        dlg.canceled.connect(_cancel)
        proc.start()

    def run_report(self):
        input_file = self.input_entry.text().strip()
        outdir = self.outdir_entry.text().strip()
        anamnesis_folder = self.anamnesis_entry.text().strip()

        if not (input_file and outdir and anamnesis_folder):
            QMessageBox.critical(self, "Error" if self.lang == "English" else "Errore", self.tr("Select all required inputs."))
            return

        os.makedirs(outdir, exist_ok=True)

        r_script = resource_path("R/report.R")
        r_exe = shutil.which("Rscript")
        if not r_exe:
            QMessageBox.critical(self, "Error" if self.lang == "English" else "Errore", self.tr("Rscript not found in PATH."))
            return

        report_language = "en" if self.lang == "English" else "it"

        cmd = [r_exe, r_script,
               "--input", input_file,
               "--output", outdir,
               "--anamnesis", anamnesis_folder,
               "--language", report_language]

        self._run_process_async(cmd, cwd=os.path.dirname(r_script), title="Report", label_text=self.tr("Generating report..."))


# ========= MAIN WINDOW =========
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("IrisBiome - Microbiome Analysis Suite (Portfolio preview)")
        self.resize(1000, 800)
        self.setWindowIcon(QIcon(resource_path("assets/logo.png")))
        # Tabs
        tabs = QTabWidget()
        pipeline_tab = PipelineTab()
        anamnesi_tab = AnamnesiTab()
        report_tab = ReportTab()
        pipeline_tab.lang_toggle.currentTextChanged.connect(anamnesi_tab.set_language)
        pipeline_tab.lang_toggle.currentTextChanged.connect(report_tab.set_language)
        anamnesi_tab.lang_toggle.currentTextChanged.connect(pipeline_tab.lang_toggle.setCurrentText)
        report_tab.lang_toggle.currentTextChanged.connect(pipeline_tab.lang_toggle.setCurrentText)
        anamnesi_tab.set_language(pipeline_tab.lang_toggle.currentText())
        report_tab.set_language(pipeline_tab.lang_toggle.currentText())
        tabs.addTab(pipeline_tab, "Pipeline")
        tabs.addTab(anamnesi_tab, "Anamnesi")
        tabs.addTab(report_tab, "Report")

        def update_tab_labels(lang: str):
            tabs.setTabText(1, "Anamnesis" if lang == "English" else "Anamnesi")

        pipeline_tab.lang_toggle.currentTextChanged.connect(update_tab_labels)
        anamnesi_tab.lang_toggle.currentTextChanged.connect(update_tab_labels)
        update_tab_labels(pipeline_tab.lang_toggle.currentText())

        container = QWidget()
        v = QVBoxLayout(container)
        v.addWidget(tabs)
        self.setCentralWidget(container)

        # Bottone apri log
        open_log_btn = QPushButton("Apri file di log")
        open_log_btn.clicked.connect(lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(get_log_path())))
        v.addWidget(open_log_btn, alignment=Qt.AlignRight)


# ========= AVVIO APP =========
if __name__ == "__main__":
    app = QApplication(sys.argv)

    # Splash screen
    splash_pix = QPixmap(resource_path("assets/logo.png"))
    splash_pix = splash_pix.scaledToWidth(300, Qt.SmoothTransformation)
    splash = QSplashScreen(splash_pix, Qt.WindowStaysOnTopHint)
    if not splash_pix.mask().isNull():
        splash.setMask(splash_pix.mask())

    splash.show()
    app.processEvents()

    def start_main():
        global w
        w = MainWindow()
        w.show()
        splash.finish(w)

    QTimer.singleShot(1000, start_main)
    sys.exit(app.exec_())

