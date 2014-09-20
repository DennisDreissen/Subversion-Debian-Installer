#!/bin/bash
# Subversion installer.

# This installer ONLY works on Debian based systems.

if [[ "$USER" != 'root' ]]; then
    echo "Sorry, but you need to run this installer as root."
    exit
fi


if [[ ! -e /etc/debian_version ]]; then
    echo "You aren't running this installer on a Debian-based system."
    exit
fi

if [[ -n $(which svn) ]];  then
    while :
    do
    clear
        echo "What do you want to do?"
        echo ""
        echo "1) Create a new repository"
        echo "2) Remove an existing repository"
        echo "3) Create a new user"
        echo "4) Remove an existing user"
        echo "5) Uninstall"
        echo "6) Exit"
        echo ""
        read -p "Select an option [1-6]: " OPTION
        case $OPTION in
                1)
                echo ""
                echo "Give the new repository a name."
                read -p "Name: " -e -i '' NAME

                if [[ -d "/var/svn/repository/$NAME" ]]; then
                    echo "There's already a repository with this name. Aborting..."
                    exit
                fi

                sudo -u www-data svnadmin create /var/svn/repository/$NAME

                echo "A new repository with the name $NAME has been created."
                exit
                ;;
                2)
                echo ""
                echo "Enter the name of the repository you want to delete."
                read -p "Name: " -e -i '' NAME

                if [[ ! -d "/var/svn/repository/$NAME" ]]; then
                    echo "There's no repository with this name. Aborting..."
                    exit
                fi

                rm -rf /var/svn/repository/$NAME

                echo "Repository with the name $NAME has been deleted."
                exit
                ;;
                3)
                echo ""
                echo "Give your user a unique username."
                read -p "Username: " -e -i '' UNAME

                if [[ -d "/var/svn/users/$UNAME.passwd" ]]; then
                    echo "There's already a user with this username. Aborting..."
                    exit
                fi

                echo ""
                echo "Which repository do you want to assign to this user?"
                read -p "Repository name: " -e -i '' RNAME

                if [[ ! -d "/var/svn/repository/$RNAME" ]]; then
                    echo ""
                    echo "There's no repository with this name."
                    read -p "Do you want to create it [Y/n]? " -e -i '' CREATE
                    
                    if [[ "$CREATE" == "y" ]]; then
                        sudo -u www-data svnadmin create /var/svn/repository/$RNAME

                        echo ""
                        echo "A new repository with the name $RNAME has been created."
                    else
                        echo "Aborting..."
                        exit
                    fi
                fi

                echo ""
                echo "Enter a strong password for the new user."
                htpasswd -c /var/svn/users/$UNAME.passwd $UNAME > /dev/null 2>&1


                echo -e "#1$UNAME\n<Location /svn/$UNAME>\nDAV svn\nSVNPath /var/svn/repository/$RNAME\nAuthType Basic\nAuthUserFile /var/svn/users/$UNAME.passwd\nAuthName \"$UNAME\"\nRequire valid-user\n</Location>\n#2$UNAME" >> /etc/apache2/mods-enabled/dav_svn.conf
                service apache2 restart > /dev/null

                echo ""
                echo "New user with username $UNAME has been created."

                exit
                ;;
                4)
                echo ""
                echo "Enter the username of the user you want to delete."
                read -p "Username: " -e -i '' UNAME

                sed -i "/#1$UNAME/,/#2$UNAME/d" /etc/apache2/mods-enabled/dav_svn.conf
                sudo rm -rf /var/svn/users/$UNAME.passwd $UNAME
                service apache2 restart > /dev/null

                echo ""
                echo "User with username $UNAME has been deleted."
                exit
                ;;
                5)
                echo ""
                read -p "Do you want to uninstall subversion [Y/n]? " -e -i 'y' SUBVERSION
                read -p "Do you want to uninstall apache2 [Y/n]? " -e -i 'n' APACHE
                read -p "Do you want to remove all users and repositories [Y/n]? " -e -i 'y' PURGE
                echo ""

                if [[ "$SUBVERSION" == "y" ]]; then
                    echo "Removing subversion and libapache2-svn..."
                    sudo apt-get purge subversion libapache2-svn -y > /dev/null
                fi

                if [[ "$APACHE" == "y" ]]; then
                    echo "Removing apache2..."
                    sudo service apache2 stop > /dev/null
                    sudo apt-get purge apache2 apache2-utils apache2.2-bin apache2-common -y > /dev/null
                    sudo rm -rf /etc/apache2 > /dev/null
                fi

                if [[ "$PURGE" == "y" ]]; then
                    echo "Removing users and repositories..."
                    rm -rf /var/svn
                fi

                if [[ "$APACHE" == "n" ]]; then
                    echo "Restarting apache2..."
                    service apache2 restart > /dev/null
                fi

                echo ""
                echo "Uninstalling selected software has been completed."
                exit
                ;;
                6) exit;;
        esac
    done

else
    echo "Welcome to this subversion installer."
    echo "You don't have all the required software installed, so lets do that first."
    echo ""
    read -n1 -r -p "Press any key to start the installation..."
    echo ""

    echo "Updating package list..."
    apt-get update > /dev/null

    if [[ ! -n $(which apache2) ]];  then
        echo ""
        echo "Subversion requires apache2 to be installed."
        echo "If you already have another webserver installed or if you do not want to run apache2 on port 80, change it below."
        read -p "Port: " -e -i 80 PORT

        echo ""
        echo "Installing apache2..."

        apt-get update > /dev/null
        apt-get install apache2 -y > /dev/null

        if [[ "$PORT" != "80" ]]; then
            sed -i "s|Listen 80|Listen $PORT|" /etc/apache2/ports.conf
            sed -i "s|*:80|*:$PORT|" /etc/apache2/ports.conf
            sed -i "s|*:80|*:$PORT|" /etc/apache2/sites-enabled/000-default
        fi
    fi

    echo "Installing subversion and libapache2-svn..."

    apt-get install subversion libapache2-svn sudo -y > /dev/null

    mkdir /var/svn
    mkdir /var/svn/repository
    mkdir /var/svn/users

    chown www-data:www-data -R /var/svn/repository
    chmod 770 -R /var/svn/repository

    echo -n "" > /etc/apache2/mods-enabled/dav_svn.conf

    echo ""
    echo "Apache2 and subversion have been installed. Run this installer again to create repo's and users."
fi