# Setup for newbies

New to R? No worries. This guide takes you from zero to your first PDF.
Do the steps in order. Don't skip any.

There are 3 parts:

1. **Install the tools** (once). Pick Mac or Windows below.
2. **Get the project** (once).
3. **Run it** (every time).

## Part 1 on a Mac

**Step 1: install R**
1. Go to [cran.r-project.org](https://cran.r-project.org).
2. Click *Download R for macOS*.
3. Check which chip your Mac has. Click the Apple logo (top left) → *About This Mac*. Look at *Chip*.
   - It says *Apple M1, M2, M3…*? Download the file that ends in `arm64.pkg`.
   - It says *Intel*? Download the file that ends in `x86_64.pkg`.
4. Open the downloaded file. Click *Continue* until it says it's done.

**Step 2: install RStudio**
1. Go to [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop/).
2. Download RStudio for macOS.
3. Open the file and drag RStudio into *Applications*.

**Step 3: install git**
1. Press `Cmd + Space`, type `Terminal` and press Enter. A window with text opens.
2. Type `git --version` and press Enter.
3. You see something like `git version 2.39`? You already have git. Close the window.
4. A pop-up asks to install the "command line developer tools"? Click *Install* and wait until it's done. This can take 10 minutes.

Done? Go to Part 2.

## Part 1 on Windows

**Step 1: install R**
1. Go to [cran.r-project.org](https://cran.r-project.org).
2. Click *Download R for Windows*, then *base*, then the big download link at the top.
3. Open the file. Click *Next* on every screen. Keep the default options.

**Step 2: install Rtools**
1. Go back to [cran.r-project.org](https://cran.r-project.org) → *Download R for Windows* → *Rtools*.
2. Pick the Rtools with the same number as your R. R 4.5 → *Rtools45*. R 4.4 → *Rtools44*.
3. Download the installer, open it and keep clicking *Next*.

**Step 3: install RStudio**
1. Go to [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop/).
2. Download RStudio for Windows and install it. Keep the default options.

**Step 4: install git**
1. Go to [git-scm.com/downloads](https://git-scm.com/downloads) and click *Windows*.
2. Download the installer and open it.
3. There are a lot of screens. Just click *Next* on every one. The defaults are fine.

Done? Go to Part 2.

## Part 2: get the project (Mac and Windows)

1. Open RStudio. Was it already open? Close it and open it again, otherwise it won't find git.
2. In the top menu, click *File* → *New Project…*
3. Click *Version Control*, then *Git*.
4. At *Repository URL*, paste: `https://github.com/batistedecat/etf-model-1.git`
5. *Project directory name* fills itself in. Leave it.
6. At *Create project as subdirectory of*, click *Browse* and pick your *Documents* folder.
7. Click *Create Project*.

RStudio now downloads the project and opens it. You see `etf-model-1` in the top right corner. That means it worked.

## Part 3: run it

Every command below goes in the **Console**. That's the panel with the `>` sign, bottom left in RStudio.
Paste the command after the `>` and press Enter. Wait until the `>` comes back before you do the next one.

1. Install the packages (only the first time):
   ```r
   renv::restore()
   ```
   It asks *Do you want to proceed?* Type `Y` and press Enter. This can take 10 minutes or more.
2. Install LaTeX (only the first time):
   ```r
   tinytex::install_tinytex()
   ```
   When it's done, close RStudio and open it again. The project opens by itself.
3. Run the engine:
   ```r
   source("run_all.R")
   ```
   Give it a minute.
4. Open the *Files* panel (bottom right) and click the `out` folder. Click a PDF to open it.

That's it. You made your first ETF report.

**Next time** you only need step 3: open RStudio, paste `source("run_all.R")`, done.

## Stuck?

| You see | Do this |
|:--|:--|
| No *Version Control* option, or "git not found" | *Tools* → *Global Options* → *Git/SVN*. Check that *Git executable* is filled in. Restart RStudio. |
| Errors about a compiler while installing packages | Mac: open Terminal and run `xcode-select --install`. Windows: install Rtools (Part 1, step 2). |
| `could not find function "%\|\|%"` | Your R is too old. Install the newest R (Part 1, step 1). |
| A LaTeX error when making the PDFs | Restart RStudio and run again. Still broken? Run `tinytex::install_tinytex()` once more. |
| An error about Yahoo or a download | Check your internet. Wait a minute and run again. |

Back to the [README](README.md).
