# Le Gradient · Analyser — Docker-image voor Render
FROM rocker/r-ver:4.5.2
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    RENV_CONFIG_REPOS_OVERRIDE=https://p3m.dev/cran/__linux__/noble/latest
RUN apt-get update && apt-get install -y --no-install-recommends \
      pandoc \
      texlive-xetex texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended lmodern \
      libcurl4-openssl-dev libssl-dev libxml2-dev zlib1g-dev libuv1-dev cmake curl \
      fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY renv.lock .Rprofile ./
COPY renv/activate.R renv/settings.json renv/
RUN R -e "renv::restore(prompt = FALSE)"
COPY . .
EXPOSE 10000
CMD ["R", "--no-save", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = as.integer(Sys.getenv('PORT', '10000')), launch.browser = FALSE)"]
