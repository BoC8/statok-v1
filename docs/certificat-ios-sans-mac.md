# Refaire le certificat de signature iOS — depuis Windows, sans Mac

> Contexte : le `.p12` de février 2026 a été exposé publiquement sur GitHub. Il faut le
> remplacer, puis le révoquer.
>
> **Ordre important** : on crée d'abord le nouveau certificat, on vérifie que le build
> CI passe, **et seulement ensuite** on révoque l'ancien. Sinon le CI casse entre les
> deux.
>
> Durée : ~30 minutes. Aucun Mac requis.

---

## Ce dont tu as besoin

- **OpenSSL** — déjà installé si tu as Git pour Windows.
  Ouvre **Git Bash** et tape `openssl version`. Si ça répond, c'est bon.
  Sinon : `winget install ShiningLight.OpenSSL.Light`
- Un accès à [developer.apple.com/account](https://developer.apple.com/account)
- Un accès aux Settings → Secrets de ton dépôt GitHub

**Repère de l'ancien certificat** (pour le retrouver dans le portail Apple) :
- Team ID : `PA6FLKZR2D`
- Créé le : **10 février 2026** — il expire donc vers février 2027
- Le CSR d'origine portait le nom `CertificateStatok`

---

## Étape 1 — Générer la clé privée et le CSR (sur ta machine)

Dans **Git Bash**, place-toi dans un dossier **hors du dépôt Git** — par exemple
`C:\Users\cleme\certificats-statok` :

```bash
mkdir -p /c/Users/cleme/certificats-statok
cd /c/Users/cleme/certificats-statok

# 1. La clé privée — c'est LE fichier à ne jamais perdre ni partager
openssl genrsa -out statok-distribution.key 2048

# 2. La demande de certificat (CSR) à envoyer à Apple
openssl req -new \
  -key statok-distribution.key \
  -out statok-distribution.csr \
  -subj "/emailAddress=clement.bolomey44@gmail.com/CN=Statok Distribution/C=FR"
```

C'est exactement ce que fait « Keychain Access → Request a Certificate » sur un Mac.
Le Mac n'apporte rien de plus.

> ⚠️ **Ce dossier ne doit jamais entrer dans le dépôt Git.** C'est pour ça qu'on le
> place ailleurs que dans `statok/`.

---

## Étape 2 — Obtenir le certificat auprès d'Apple

1. [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
2. Bouton **+**
3. Type : **Apple Distribution** (ou *iOS Distribution (App Store and Ad Hoc)*)
4. **Choose File** → sélectionne `statok-distribution.csr`
5. **Continue** → **Download** → tu récupères `distribution.cer`

> **Si Apple refuse en disant que tu as atteint la limite de certificats** : c'est le
> moment de révoquer l'ancien (celui du 10 février 2026). C'est de toute façon
> l'objectif — dans ce cas, l'ordre s'inverse simplement, révoque puis recrée.

Place `distribution.cer` dans le même dossier que ta clé.

---

## Étape 3 — Fabriquer le `.p12`

Toujours dans Git Bash, même dossier :

```bash
# 1. Convertir le certificat Apple (format DER) en PEM
openssl x509 -inform DER -in distribution.cer -out distribution.pem

# 2. Combiner certificat + clé privée en un .p12
openssl pkcs12 -export -legacy \
  -inkey statok-distribution.key \
  -in distribution.pem \
  -out Certificates.p12 \
  -name "Statok Distribution"
```

OpenSSL demande un mot de passe : **choisis-en un solide et note-le**, c'est lui qui
ira dans le secret `P12_PASSWORD`.

> Le `-legacy` n'est pas décoratif : sans lui, OpenSSL 3 produit un `.p12` chiffré d'une
> façon que l'outil `security import` de macOS refuse parfois. C'est la cause n°1 des
> échecs de CI sur cette manip.

Vérification :

```bash
openssl pkcs12 -in Certificates.p12 -nokeys -info -legacy | openssl x509 -noout -subject -dates
```

Tu dois voir `Apple Distribution: ...` et une validité d'environ un an.

---

## Étape 4 — Le provisioning profile

1. [developer.apple.com/account/resources/profiles](https://developer.apple.com/account/resources/profiles)
2. **+** → **App Store Connect** (distribution)
3. App ID : `com.example.statok`
4. Certificat : **le nouveau** que tu viens de créer
5. Nomme-le `Statok_Distribution_Profile` — le workflow CI attend précisément ce nom
6. **Download** → `Statok_Distribution_Profile.mobileprovision`

> Note pour plus tard, sans urgence : ton bundle ID est `com.example.statok`, le
> placeholder généré par `flutter create`. Ça fonctionne, mais ça se voit. Le changer
> reviendrait à créer une nouvelle app sur le store — donc à ne faire que si tu es prêt
> à repartir de zéro côté App Store Connect.

---

## Étape 5 — Mettre à jour les GitHub Secrets

Encode les deux fichiers en base64. Dans **PowerShell**, depuis le dossier des
certificats :

```powershell
cd C:\Users\cleme\certificats-statok

# Copie la valeur du .p12 dans le presse-papier
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Certificates.p12")) | Set-Clipboard
```

→ colle dans le secret **`P12_BASE64`**
(GitHub → ton dépôt → Settings → Secrets and variables → Actions)

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Statok_Distribution_Profile.mobileprovision")) | Set-Clipboard
```

→ colle dans **`MOBILEPROVISION_BASE64`**

Puis mets à jour **`P12_PASSWORD`** avec le mot de passe de l'étape 3.

Les autres secrets (`KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_*`) ne changent pas.

---

## Étape 6 — Vérifier, puis révoquer

1. Pousse un commit sur `main` (ou relance le workflow à la main depuis l'onglet
   Actions).
2. Attends que **« Build iOS IPA » passe au vert.**
3. **Alors seulement** : portail Apple → Certificates → sélectionne le certificat du
   **10 février 2026** → **Revoke**.

Tant que l'étape 2 n'est pas verte, ne révoque rien.

---

## Sauvegarde

Range `statok-distribution.key`, `Certificates.p12` et son mot de passe dans ton
gestionnaire de mots de passe, ou sur une clé USB. Sans la clé privée, un certificat
Apple ne sert à rien — et c'est exactement ce qui rend la manip pénible quand on la
refait un an plus tard sans savoir où sont les fichiers.

**À ne jamais remettre dans le dépôt Git.** Le `.gitignore` bloque désormais
`*.p12`, `*.cer`, `*.mobileprovision` et `certificates-mac/`, mais la meilleure
protection reste de garder ces fichiers hors du dossier du projet.

---

## Piste pour supprimer le problème définitivement

Ton workflow fait déjà `flutter build ipa --no-codesign` puis signe à l'export avec
`xcodebuild -exportArchive -allowProvisioningUpdates`. Et tu as déjà les secrets
`APP_STORE_CONNECT_KEY_CONTENT` / `KEY_ID` / `ISSUER_ID`.

Il existe un mode « cloud signing » où Xcode demande à Apple de gérer le certificat de
distribution via cette clé API, **sans `.p12` du tout**. Il faudrait :

- passer `ExportOptions.plist` de `signingStyle: manual` à `automatic`
- ajouter à `xcodebuild` : `-authenticationKeyPath`, `-authenticationKeyID`,
  `-authenticationKeyIssuerID`
- supprimer entièrement l'étape « Import Certificate (.p12) »

Conditions : la clé App Store Connect doit avoir le rôle **Admin** (c'est le cas pour un
compte individuel dont tu es le titulaire). Ça vaut le coup d'essayer **une fois que le
build actuel remarche** — pas maintenant, on ne change pas deux choses à la fois.
