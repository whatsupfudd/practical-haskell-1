# should match the GHC version of the stack.yaml resolver
# checked in CI
ARG GHC_VERSION=9.4.7

FROM ubuntu:22.04 AS os_base

# Install Ubuntu packages needed for IHaskell runtime
# zeromq-dev cairo-dev pango-dev file-dev blas-dev build-base gmp-dev libpq-dev 
RUN apt-get update \
    && apt-get install -y vim nodejs curl \
            libzmq5 libzmq3-dev pkg-config \
            libcairo2-dev libpango1.0-dev libmagic-dev \
            libblas-dev liblapack-dev libpq-dev \
            libtinfo-dev \
    && rm -rf /var/cache/apk/*

ENV IHASKELL_PACKAGES /usr/local/lib/ihaskell/packages/pkgdb

FROM os_base AS ihaskell_base

WORKDIR /build

RUN curl -sSL https://get.haskellstack.org/ | sh

# $GHC_VERSION
RUN stack setup 9.4.7 --system-ghc
RUN stack update

from ihaskell_base as builder

# Build snapshot

COPY stack_docker.yaml stack.yaml
COPY ihaskell.cabal ihaskell.cabal
COPY ipython-kernel ipython-kernel
COPY ghc-parser ghc-parser
COPY inline-js inline-js
COPY ihaskell-display ihaskell-display
COPY servant-errors servant-errors
# Use -j1 on small machines to avoid running out of memory.


RUN stack build ihaskell --only-snapshot


# Build IHaskell itself.
# Don't just `COPY .` so that changes in e.g. README.md don't trigger rebuild.
COPY src src
COPY html html
COPY main main
COPY jupyterlab-ihaskell jupyterlab-ihaskell
COPY LICENSE LICENSE


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

RUN stack setup --resolver=$(cat /build/resolver.txt) --system-ghc
RUN stack config set system-ghc --global true

# Set up env file
RUN stack exec env --system-ghc \
  | sed "s#\(GHC_PACKAGE_PATH\)=.*#\1=${IHASKELL_PACKAGES}:$(cat /build/build_snapshot_pkg_db.txt):$(stack path --global-pkg-db)#" \
  > /tmp/env.ihaskell

COPY docker_kernel.json docker_kernel.json

FROM os_base AS jhaskell

# Install JupyterLab
# python3-pip python3-jupyterlab-server python3-notebook python3-jupyter-client 
RUN apt update \
    && apt install -y python3-pip \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install -U pip \
    && pip3 install -U jupyterlab notebook jupyter-server-proxy

# Create runtime user
ENV NB_USER jovyan
ENV NB_UID 1000
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER} \
    && mkdir /home/${NB_USER}/.ihaskell \
    && chown -R ${NB_UID} /home/${NB_USER} \
    && ln -s /home/${NB_USER}/.ihaskell /root/.ihaskell \
    && chown -R ${NB_UID} /root/.ihaskell

# Very hacky way to get libgmp to run.
RUN ln -s /usr/lib/x86_64-linux-gnu/libgmp.so.10 /usr/lib/x86_64-linux-gnu/libgmp.so

# Move over the IHaskell packages and runtime environment.
COPY --from=builder --chown=${NB_UID} /root/.stack/snapshots /root/.stack/snapshots
COPY --from=builder --chown=${NB_UID} /root/.stack/programs /root/.stack/programs

# Create directory for storing ihaskell files
ENV IHASKELL_DATA_DIR /usr/local/lib/ihaskell
RUN mkdir -p ${IHASKELL_DATA_DIR} && chown ${NB_UID} ${IHASKELL_DATA_DIR}
COPY --from=builder --chown=${NB_UID} /tmp/env.ihaskell ${IHASKELL_DATA_DIR}/env
COPY --from=builder --chown=${NB_UID} /usr/local/lib/ihaskell/packages /usr/local/lib/ihaskell/packages
# COPY --from=builder /usr/local/lib/ihaskell/packages/bin/ihaskell /usr/local/bin
RUN ln -s /usr/local/lib/ihaskell/packages/bin/ihaskell /usr/local/bin/ihaskell


# Set up + set hlint data directory
ENV HLINT_DATA_DIR /usr/local/lib/hlint
COPY --from=builder --chown=${NB_UID} /data/hlint.yaml ${HLINT_DATA_DIR}/
ENV hlint_datadir ${HLINT_DATA_DIR}

# Set current user + directory
WORKDIR /home/${NB_USER}/src
RUN chown -R ${NB_UID} /home/${NB_USER}/src
USER ${NB_UID}

# Set up global project
#COPY --from=builder --chown=${NB_UID} /build/resolver.txt /tmp/
#COPY --from=builder --chown=${NB_UID} /build/build_snapshot_pkg_db.txt /tmp/
#COPY --from=builder --chown=${NB_UID} /build/build_local_pkg_db.txt /tmp/
#COPY --from=builder --chown=${NB_UID} /build/build_snapshot_root.txt /tmp/

# Install + setup IHaskell
# COPY --from=builder --chown=${NB_UID} /build/bin/ihaskell /usr/local/bin/
COPY --from=builder --chown=${NB_UID} /build/html ${IHASKELL_DATA_DIR}/html
COPY --from=builder --chown=${NB_UID} /build/jupyterlab-ihaskell ${IHASKELL_DATA_DIR}/jupyterlab-ihaskell

RUN export ihaskell_datadir=${IHASKELL_DATA_DIR} \
    && ihaskell install --env-file ${IHASKELL_DATA_DIR}/env
RUN jupyter notebook --generate-config

COPY --chown=${NB_UID} notebooks_2 /home/${NB_USER}/src/notebooks
# Why didn't the ihaskell install worked?
COPY --chown=${NB_UID} docker_kernel.json /home/${NB_USER}/.local/share/jupyter/kernels/haskell/kernel.json
COPY --chown=${NB_UID} DockerSetup/jupyter_server_config.py /home/${NB_USER}/.jupyter/jupyter_server_config.py
COPY --chown=${NB_UID} DockerSetup/jupyter_server_config.json /home/${NB_USER}/.jupyter/jupyter_server_config.json

USER 0
RUN chmod 755 /root
USER ${NB_UID}

EXPOSE 8888 8181 8080
CMD ["jupyter-lab", "notebooks", "--ip", "0.0.0.0", "--no-browser", "--debug" ]
