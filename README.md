# select-freeboxos v3.1.0:

## Instructions d'installation:

Voir les instructions d'installation sur la page de votre compte à l'adresse www.media-select.fr

Afin de changer le paramétrage après l'installation, vous pouvez modifier le fichier config.json situé dans le dossier $HOME/.config/select_freeboxos

Exemple de commande à lancer:

nano ~/.config/select_freeboxos/config.json

Vous pourrez ainsi modifier des paramètres sans avoir à relancer le programme install.py

## Sécurité et modes de connexion

Ce programme automatise l’accès à l’interface **Freebox OS** afin de programmer
des enregistrements TV sans intervention manuelle.
Il manipule des **identifiants administrateur sensibles**. Une attention
particulière est donc portée à la sécurité.


### Modes de connexion

Le programme peut fonctionner dans trois contextes distincts :

#### 🟢 Mode local (recommandé)
- Exécution sur un ordinateur **toujours présent sur le réseau domestique**
- Connexion directe à la Freebox via le réseau local
- HTTP autorisé uniquement dans ce contexte

Conditions :
- réseau privé et de confiance
- machine non utilisée hors du domicile

#### 🟡 Mode distant sécurisé
- Exécution possible depuis des réseaux externes
- **HTTPS obligatoire**
- Communications chiffrées
- Risque maîtrisé

Ce mode est requis si l’ordinateur est portable ou utilisé en déplacement.

#### 🔴 Mode distant non sécurisé (déconseillé / bloqué)
- Connexion HTTP depuis Internet ou un réseau public
- Exposition possible du mot de passe administrateur

Ce mode est **automatiquement bloqué** par le programme.

### Protection automatique

Par défaut, le programme active un **mode de sécurité stricte** :

- Les connexions HTTP sont autorisées uniquement lorsque la Freebox
résout vers une adresse IP privée (réseau local).
- Si l’adresse détectée est publique et que HTTPS est désactivé,
le programme s’arrête pour éviter l’exposition du mot de passe.
