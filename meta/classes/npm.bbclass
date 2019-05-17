DEPENDS_prepend = "nodejs-native "
RDEPENDS_${PN}_prepend = "nodejs "
S = "${WORKDIR}/npmpkg"

def node_pkgname(d):
    bpn = d.getVar('BPN')
    if bpn.startswith("node-"):
        return bpn[5:]
    return bpn

NPMPN ?= "${@node_pkgname(d)}"

NPM_INSTALLDIR = "${libdir}/node/${NPMPN}"

# function maps arch names to npm arch names
def npm_oe_arch_map(target_arch, d):
    import re
    if   re.match('p(pc|owerpc)(|64)', target_arch): return 'ppc'
    elif re.match('i.86$', target_arch): return 'ia32'
    elif re.match('x86_64$', target_arch): return 'x64'
    elif re.match('arm64$', target_arch): return 'arm'
    return target_arch

NPM_ARCH ?= "${@npm_oe_arch_map(d.getVar('TARGET_ARCH'), d)}"
NPM_INSTALL_DEV ?= "0"

npm_do_compile() {
	# Copy in any additionally fetched modules
	if [ -d ${WORKDIR}/node_modules ] ; then
		cp -a ${WORKDIR}/node_modules ${S}/
	fi
	# changing the home directory to the working directory, the .npmrc will
	# be created in this directory
	export HOME=${WORKDIR}
	if [  "${NPM_INSTALL_DEV}" = "1" ]; then
		npm config set dev true
	else
		npm config set dev false
	fi
	npm set cache ${WORKDIR}/npm_cache
	# clear cache before every build
	npm cache clear --force
	# Install pkg into ${S} without going to the registry
	if [  "${NPM_INSTALL_DEV}" = "1" ]; then
		npm --arch=${NPM_ARCH} --target_arch=${NPM_ARCH} --no-registry install
	else
		npm --arch=${NPM_ARCH} --target_arch=${NPM_ARCH} --production --no-registry install
	fi
}

npm_do_install() {
	# changing the home directory to the working directory, the .npmrc will
	# be created in this directory
	export HOME=${WORKDIR}
	mkdir -p ${D}${libdir}/node_modules
	local NPM_PACKFILE=$(npm pack .)
	npm install --prefix ${D}${prefix} -g --arch=${NPM_ARCH} --target_arch=${NPM_ARCH} --production --no-registry ${NPM_PACKFILE}
	mv ${D}${libdir}/node_modules ${D}${libdir}/node
	if [ -d ${D}${prefix}/etc ] ; then
		# This will be empty
		rmdir ${D}${prefix}/etc
	fi
}

python populate_packages_prepend () {
    instdir = d.expand('${D}${NPM_INSTALLDIR}')
    extrapackages = oe.package.npm_split_package_dirs(instdir)
    pkgnames = extrapackages.keys()
    d.prependVar('PACKAGES', '%s ' % ' '.join(pkgnames))
    for pkgname in pkgnames:
        pkgrelpath, pdata = extrapackages[pkgname]
        pkgpath = '${NPM_INSTALLDIR}/' + pkgrelpath
        # package names can't have underscores but npm packages sometimes use them
        oe_pkg_name = pkgname.replace('_', '-')
        expanded_pkgname = d.expand(oe_pkg_name)
        d.setVar('FILES_%s' % expanded_pkgname, pkgpath)
        if pdata:
            version = pdata.get('version', None)
            if version:
                d.setVar('PKGV_%s' % expanded_pkgname, version)
            description = pdata.get('description', None)
            if description:
                d.setVar('SUMMARY_%s' % expanded_pkgname, description.replace(u"\u2018", "'").replace(u"\u2019", "'"))
    d.appendVar('RDEPENDS_%s' % d.getVar('PN'), ' %s' % ' '.join(pkgnames).replace('_', '-'))
}

FILES_${PN} += " \
    ${NPM_INSTALLDIR} \
"

EXPORT_FUNCTIONS do_compile do_install
