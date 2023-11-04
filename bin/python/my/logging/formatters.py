import logging
import sys


class SysLogFormatter(logging.Formatter):
    IS_ATTY = sys.stdout.isatty()
    LEVELNO_TO_SYSLOG = {
        logging.ERROR: 3,
        logging.CRITICAL: 2,
        logging.WARNING: 4,
        logging.INFO: 6,
        logging.DEBUG: 7,
    }

    def __init__(
        self,
        *,
        color: bool = IS_ATTY,
        time: bool = IS_ATTY,
        file: bool = False,
    ):
        super().__init__(
            ("[%(asctime)s] " if time else "")
            + ("[%(funcName)s() at %(filename)s:%(lineno)d] " if file else "")
            + "%(module)s: %(message)s",
        )
        self.color = color

    def format(self, record):
        level = self.LEVELNO_TO_SYSLOG[record.levelno]
        s = super().format(record).splitlines()
        s = "\n<c>".join(s)
        s = f"<{level}>{s}"

        if self.color:
            match record.levelno:
                case logging.ERROR | logging.CRITICAL:
                    return f"\033[1;31m{s}\033[m"
                case logging.WARNING:
                    return f"\033[1;33m{s}\033[m"
                case logging.INFO:
                    return f"\033[1;34m{s}\033[m"
                case logging.DEBUG:
                    return f"\033[37m{s}\033[m"
        return s
