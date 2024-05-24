# Configuration file for jupyter-server.
c = get_config()  #noqa

c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True

