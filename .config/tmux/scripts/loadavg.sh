#!/bin/sh
printf "#[fg=colour107]%s #[fg=colour210]%s %s#[fg=colour243]" $(cut -d ' ' -f -3 /proc/loadavg)
