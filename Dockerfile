# should match the GHC version of the stack.yaml resolver
# checked in CI
ARG GHC_VERSION=9.4.7

FROM haskell:${GHC_VERSION} AS ihaskell_base

# Install Ubuntu packages needed for IHaskell runtime
RUN apt-get update \
    && apt-get install -y libzmq5 vim nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Ubuntu packages needed for IHaskell build
RUN apt-get update \
    && apt-get install -y libzmq3-dev pkg-config \
            libcairo2-dev libpango1.0-dev libmagic-dev libblas-dev liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

ENV IHASKELL_PACKAGES /usr/local/lib/ihaskell/packages/pkgdb

FROM ihaskell_base AS builder

WORKDIR /build

RUN stack setup
RUN stack update
# Build snapshot

COPY stack_docker.yaml stack.yaml
COPY ihaskell.cabal ihaskell.cabal
COPY ipython-kernel ipython-kernel
COPY ghc-parser ghc-parser
COPY inline-js inline-js
COPY ihaskell-display ihaskell-display
COPY servant-errors servant-errors
RUN stack -j1 build ihaskell --only-snapshot


# Build IHaskell itself.
# Don't just `COPY .` so that changes in e.g. README.md don't trigger rebuild.
COPY src src
COPY html html
COPY main main
COPY jupyterlab-ihaskell jupyterlab-ihaskell
COPY LICENSE LICENSE
# RUN stack install ihaskell --local-bin-path ./bin/

# RUN cd ihaskell-display \
#    && stack build display --only-snapshot


RUN mkdir -p /usr/local/lib/ihaskell/packages/pkgdb
# ENV PROJECT_PACKAGES $(stack path --local-pkg-db)
# ENV SNAPSHOT_PACKAGES $(stack path --snapshot-pkg-db)
ENV IHASKELL_PREFIX /usr/local/lib/ihaskell/packages

COPY pkgInstall pkgInstall
COPY Setup.hs Setup.hs

RUN cd ipython-kernel && /build/pkgInstall ipython-kernel.cabal && cd .. \
  && cd ghc-parser && /build/pkgInstall ghc-parser.cabal && cd .. \
  && /build/pkgInstall ihaskell.cabal \
  && cd ihaskell-display/ihaskell-aeson && /build/pkgInstall ihaskell-aeson.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-blaze && /build/pkgInstall ihaskell-blaze.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-charts && /build/pkgInstall ihaskell-charts.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-diagrams && /build/pkgInstall ihaskell-diagrams.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-gnuplot && /build/pkgInstall ihaskell-gnuplot.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-graphviz && /build/pkgInstall ihaskell-graphviz.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-hatex && /build/pkgInstall ihaskell-hatex.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-juicypixels && /build/pkgInstall ihaskell-juicypixels.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-magic && /build/pkgInstall ihaskell-magic.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-plot && /build/pkgInstall ihaskell-plot.cabal && cd ../.. \
  && cd ihaskell-display/ihaskell-widgets && /build/pkgInstall ihaskell-widgets.cabal && cd ../.. \
  && cd inline-js/inline-js-core && /build/pkgInstall inline-js-core.cabal && cd ../.. \
  && cd inline-js/inline-js && /build/pkgInstall inline-js.cabal && cd ../.. \
  && cd servant-errors && /build/pkgInstall servant-errors.cabal && cd ../..
#   && cd ihaskell-display/ihaskell-rlangqq && /build/pkgInstall ihaskell-rlangqq.cabal && cd ../.. 
#   && cd ihaskell-display/ihaskell-static-canvas && /build/pkgInstall ihaskell-static-canvas.cabal && cd ../..

# Save resolver used to build IHaskell
RUN sed -n 's/resolver: \(.*\)/\1/p' stack.yaml | tee resolver.txt

RUN stack path --snapshot-pkg-db > build_snapshot_pkg_db.txt \
      && stack path --local-pkg-db > build_local_pkg_db.txt \
      && stack path --snapshot-install-root > build_snapshot_root.txt

# Save third-party data files
RUN mkdir /data && \
    snapshot_install_root=$(stack path --snapshot-install-root) && \
    cp $(find ${snapshot_install_root} -name hlint.yaml) /data

COPY docker_kernel.json docker_kernel.json

FROM ihaskell_base AS ihaskell

# Install JupyterLab
RUN apt-get update && \
    apt-get install -y python3-pip && \
    rm -rf /var/lib/apt/lists/*
RUN pip3 install -U pip
RUN pip3 install -U jupyterlab notebook

# Create runtime user
ENV NB_USER jovyan
ENV NB_UID 1000
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

# Create directory for storing ihaskell files
ENV IHASKELL_DATA_DIR /usr/local/lib/ihaskell
RUN mkdir -p ${IHASKELL_DATA_DIR} && chown ${NB_UID} ${IHASKELL_DATA_DIR}

# Set up + set hlint data directory
ENV HLINT_DATA_DIR /usr/local/lib/hlint
COPY --from=builder --chown=${NB_UID} /data/hlint.yaml ${HLINT_DATA_DIR}/
ENV hlint_datadir ${HLINT_DATA_DIR}

# Set current user + directory
WORKDIR /home/${NB_USER}/src
RUN chown -R ${NB_UID} /home/${NB_USER}/src
USER ${NB_UID}

# Set up global project
COPY --from=builder --chown=${NB_UID} /build/resolver.txt /tmp/
COPY --from=builder --chown=${NB_UID} /build/build_snapshot_pkg_db.txt /tmp/
COPY --from=builder --chown=${NB_UID} /build/build_local_pkg_db.txt /tmp/
COPY --from=builder --chown=${NB_UID} /build/build_snapshot_root.txt /tmp/
RUN stack setup --resolver=$(cat /tmp/resolver.txt) --system-ghc
RUN stack config set system-ghc --global true

# Set up env file
RUN stack exec env --system-ghc \
  | sed "s#\(GHC_PACKAGE_PATH\)=.*#\1=$(stack path --local-pkg-db):${IHASKELL_PACKAGES}:$(cat /tmp/build_snapshot_pkg_db.txt):$(stack path --global-pkg-db)#" \
  > ${IHASKELL_DATA_DIR}/env

# Install + setup IHaskell
# COPY --from=builder --chown=${NB_UID} /build/bin/ihaskell /usr/local/bin/
COPY --from=builder /usr/local/lib/ihaskell/packages/bin/ihaskell /usr/local/bin
COPY --from=builder --chown=${NB_UID} /build/html ${IHASKELL_DATA_DIR}/html
COPY --from=builder --chown=${NB_UID} /build/jupyterlab-ihaskell ${IHASKELL_DATA_DIR}/jupyterlab-ihaskell
COPY --from=builder --chown=${NB_UID} /usr/local/lib/ihaskell/packages /usr/local/lib/ihaskell/packages
COPY --from=builder --chown=${NB_UID} /root/.stack/snapshots /root/.stack/snapshots

RUN export ihaskell_datadir=${IHASKELL_DATA_DIR} \
    && ihaskell install --env-file ${IHASKELL_DATA_DIR}/env
RUN jupyter notebook --generate-config

COPY --chown=${NB_UID} notebooks_2 /home/${NB_USER}/src/notebooks
# Why didn't the ihaskell install worked?
COPY --chown=${NB_UID} docker_kernel.json /home/${NB_USER}/.local/share/jupyter/kernels/haskell/kernel.json
USER 0
RUN chmod 755 /root
USER ${NB_UID}

CMD ["jupyter-lab", "notebooks", "--ip", "0.0.0.0", "--no-browser" ]
