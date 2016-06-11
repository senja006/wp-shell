#!/bin/bash -e
clear

echo "Проект уже есть в удаленном хранилище git (github, bitbucket)? (y/n): "
read -e project_exist
echo "SSH удаленного репозитория? (bitbucket, github или др.): "
read -e gitremote
echo "Используется база данных? (y/n): "
read -e used_base
echo "Название рабочей ветки? (например, master, dev...): "
read -e branch
echo "Вызов wp-cli (например, php /home/senja006/wp-cli.phar. По умолчанию: wp)? : "
read -e alias_wp_cli
	alias_wp_cli=${alias_wp_cli:-wp}

if [ "$project_exist" == "n" ]; then
	echo "Инициализация репозитория..."
	git init

	echo "Добавлен удаленный репозиторий"
	git remote add origin $gitremote

	if [ "$used_base" == "y" ]; then
		echo "Бекап базы данных"
		$alias_wp_cli db export "wp-db-$branch.sql"
	fi

	echo "Скачивать gitignore для Wordpress? (y/n): "
	read -e load_gitignore
	if [ "$load_gitignore" == "y" ]; then
		echo "Скачивание .gitignore..."
		curl -L -o '.gitignore' https://raw.githubusercontent.com/github/gitignore/master/WordPress.gitignore
		cat >> .gitignore <<EOL

!.htaccess
!wp-content/uploads/
.DS_Store
._.DS_Store
.idea

wp-install.sh
wp-options.sh
wp-create-repo.sh
EOL
	fi

	echo "Первый коммит"
	git add .
	git commit -m "Старт проекта"
	if [ "$branch" == "master" ]; then
		git push -u origin --all
	else
		git checkout -b $branch
		git merge master
		git push -u origin --all
	fi
else
	echo "Клонирование репозитория..."
	rm -r *
	git clone $gitremote .
	git checkout --track origin/$branch

	#установка базы данных
	if [ "$used_base" == "y" ]; then
		echo "Для продолжения необходимо скопировать wp-config.php и создать базу данных. Продолжать? (y/n): "
		read -e wp_config_copy
		echo "Старый url?: "
		read -e old_url
		echo "Новый url?: "
		read -e new_url

		$alias_wp_cli db import "wp-db-$branch.sql"
		$alias_wp_cli search-replace $old_url $new_url
	fi
fi

#установка хуков
#перед коммитом
echo "Настройка хука pre-commit..."
cat >> .git/hooks/pre-commit <<EOL

#!/bin/bash -e
$alias_wp_cli db export wp-db-$branch.sql
git add wp-db-$branch.sql
EOL
chmod +x .git/hooks/pre-commit

#после pull
echo "Настройка хука post-merge..."
cat >> .git/hooks/post-merge <<EOL

#!/bin/bash -e
$alias_wp_cli db import "wp-db-$branch.sql"
$alias_wp_cli search-replace $old_url $new_url
EOL
chmod +x .git/hooks/post-merge

#создание скрипта для принудительного обновления удаленного сервера
echo "Создать скрипт для принудительного обновления удаленного сервера? (y/n): "
read -e install_script
if [ "$install_script" == "y" ]; then
	echo "Параметры ssh подключения (по умолчанию senja006@sra.webhost1.ru)"
	read -e ssh_connect
		ssh_connect=${ssh_connect:-senja006@sra.webhost1.ru}
	echo "Порт ssh подключения (по умолчанию 9999)"
	read -e ssh_port
		ssh_port=${ssh_port:-9999}
	echo "Папка проекта на удаленном сервере?: "
	read -e remote_folder

	dir=`pwd`
	name_file="wp-remote-pull.sh"

	cat >> $name_file <<EOL

#!/bin/bash -e
#ssh $ssh_connect -p "$ssh_port" 'bash -s' < $dir/$name_file

ssh $ssh_connect -p "$ssh_port"
cd $remote_folder
git pull origin $branch
EOL
fi

#выполнение настройки на удаленном сервере в интерактивном режиме
echo "Выполнить настройку удаленного сервера? (y/n): "
read -e install_remote_server

if [ "$install_remote_server" == "y" ]; then
	echo "Параметры ssh подключения (по умолчанию senja006@sra.webhost1.ru)"
	read -e ssh_connect
		ssh_connect=${ssh_connect:-senja006@sra.webhost1.ru}
	echo "Порт ssh подключения (по умолчанию 9999)"
	read -e ssh_port
		ssh_port=${ssh_port:-9999}
	echo "Папка проекта на удаленном сервере?: "
	read -e remote_folder

	dir=`pwd`

	ssh -t $ssh_connect -p "$ssh_port" "cd $remote_folder && $(<$dir/wp-install-server.sh)"
fi


#=========================
#добавления ключа на удаленный сервер для ssh подключения
#ssh-keygen -t rsa
#ssh-copy-id -i /Users/senja006/.ssh/id_rsa.pub senja006@sra.webhost1.ru -p "9999"

#=========================
#установка wp-cli на удаленный сервер
#curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
#chmod +x wp-cli.phar

#=========================
#копирование файла на удаленный сервер
#scp -P 9999 wp-install-server.sh senja006@sra.webhost1.ru:/home/senja006/wp-test.yarkevich.ru









