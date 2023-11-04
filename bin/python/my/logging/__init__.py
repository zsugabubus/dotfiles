from .formatters import SysLogFormatter
import logging
import os

root = logging.getLogger()
root.setLevel(os.environ.get("PYTHON_LOG", "WARNING"))

console = logging.StreamHandler()
console.setFormatter(SysLogFormatter())
root.addHandler(console)

if False:
    logging.error("ok")
    logging.info("ok")
    logging.warning("ok")
    logging.debug("ok")
    try:
        raise
    except:
        logging.exception("")
