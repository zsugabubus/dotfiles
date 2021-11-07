if [[ -o interactive && ! -o single_command && ! $0 = command ]]; then
	if [[ $PWD = ${${:-~m}:A} ]]; then
		cd ~m
	elif [[ $PWD != ~ ]]; then
		cd .
	fi
fi
