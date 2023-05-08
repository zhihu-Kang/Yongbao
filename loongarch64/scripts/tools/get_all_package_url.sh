#!/bin/bash

BASE_DIR="${PWD}"


function set_proxy
{
        declare DOMAIN=$(echo ${1} | grep -o ".\{0,\}//[^/]\{0,\}" | awk -F'/' '{print $NF}')
        declare PROXY_SERVER=$(cat proxy.set | grep -v "^#" | grep "${DOMAIN} " | awk -F' ' '{ print $2 }')
        if [ "x${PROXY_SERVER}" == "x" ]; then
                        unset https_proxy
                        unset http_proxy
        else
                        export https_proxy=${PROXY_SERVER}
                        export http_proxy=${PROXY_SERVER}
        fi
}


declare GIT_ONLY=FALSE
declare GIT_UPDATE=FALSE
declare FORCE_DOWN=FALSE
declare PROXY_MODE=0
declare INDEX_FILE=""

while getopts 'gfui:ph' OPT; do
    case $OPT in
	g)  
	    GIT_ONLY=TRUE
	    ;;
	f)  
	    FORCE_DOWN=TRUE
	    ;;
	u)
	    GIT_UPDATE=TRUE
	    ;;
	p)
	    PROXY_MODE=1
	    ;;
	i)
	    INDEX_FILE=$OPTARG
	    ;;
        h|?)
            echo "用法: `basename $0` [选项] 软件包名 软件版本 GIT地址 分支名 提交号"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

mkdir -p ${BASE_DIR}/sources/downloads/{files,hash}
mkdir -p ${BASE_DIR}/sources/git
FAIL_COUNT=1
NO_FILE="警告："
if [ ! -d logs ]; then
	mkdir -p logs
fi
echo "" > logs/download_fail.log

if [ "x${1}" == "x" ]; then
        STEP_FILE="$(cat step)"
else
        STEP_FILE="$(cat step | grep "/${1}")"
fi

declare SAVE_FILENAME=""

if [ "x${INDEX_FILE}" == "x" ]; then
	STEP_ARRAY="$(echo "${STEP_FILE}" | sed "s@%step/@@g" | awk -F'|' '{ print $1 }')"
else
	STEP_ARRAY="$(cat ${INDEX_FILE} | awk -F' ' '{ print $2 }' | sed "s@step/@@g" | awk -F'|' '{ print $1 }')"
fi

for i in ${STEP_ARRAY}
do
	PKG_NAME="$(cat scripts/step/${i}.info | awk -F'|' '{ print $1 }')"
	PKG_VERSION="$(cat scripts/step/${i}.info | awk -F'|' '{ print $2 }')"
	URL=$(cat sources/url/${i} | awk -F'|' '{ print $1 }')
	SAVE_FILENAME=$(cat sources/url/${i} | awk -F'|' '{ print $2 }')
	if [ "x${SAVE_FILENAME}" == "x" ]; then
		SAVE_FILENAME="${URL##*/}"
	fi
	if [ "x${URL}" != "x" ]; then
	        if [ "x${PROXY_MODE}" == "x1" ]; then
        	        set_proxy "${URL}"
	        fi
		case "${URL%%/*}" in
		https: | http: | ftps: | ftp: | git:)
			if [ "x${URL##*\.}" != "xgit" ] && [ ! -f sources/url/${i}.gitinfo ]; then
				if [ "x${GIT_ONLY}" == "xFALSE" ]; then
					if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME} ] && [ -f ${BASE_DIR}/sources/downloads/hash/${SAVE_FILENAME}.hash ] && [ "x$(md5sum ${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${BASE_DIR}/sources/downloads/hash/${SAVE_FILENAME}.hash)" ]; then
						echo "$i 所需源码包已下载。"
					else
						if [ "x${FORCE_DOWN}" == "xTRUE" ]; then
							rm -f ${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME}
						fi
						echo "下载：$i 所需源码包到${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME}..."
						# wget -c ${URL} -O ${BASE_DIR}/sources/downloads/files/${URL##*/}
						wget -c ${URL} -O ${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME}
						if [ "x$?" != "x0" ]; then
							echo "${URL} 下载失败！"
							echo "下载 ${URL} 失败！" >> logs/download_fail.log
							((FAIL_COUNT++))
							continue;
						fi
						md5sum ${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME} | awk -F' ' '{print $1}' > ${BASE_DIR}/sources/downloads/hash/${SAVE_FILENAME}.hash
					fi
				fi
			else
				if [ -f sources/url/${i}.gitinfo ]; then
					PKG_GIT_BRANCH="$(cat sources/url/${i}.gitinfo | awk -F'|' '{ print $1 }')"
					PKG_GIT_COMMIT="$(cat sources/url/${i}.gitinfo | awk -F'|' '{ print $2 }')"
					PKG_GIT_SUBMODULE="$(cat sources/url/${i}.gitinfo | awk -F'|' '{ print $3 }')"
				else
					PKG_GIT_BRANCH=""
					PKG_GIT_COMMIT=""
					PKG_GIT_SUBMODULE="0"
				fi
				if ( [ "x${FORCE_DOWN}" == "xFALSE" ] || [ "x$(eval echo \${FORCE_$(echo ${PKG_NAME}_${PKG_VERSION} | sed -e "s@-@_@g" -e "s@\.@_@g" )_git})" == "x1" ] ) && [ -f ${BASE_DIR}/sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ] && [ -f ${BASE_DIR}/sources/downloads/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash ]; then
					echo "$i 所需源码包已下载。"
				else
					if [ -f ${BASE_DIR}/sources/downloads/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash ]; then
						rm -f ${BASE_DIR}/sources/downloads/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash
					fi
					if [ -f ${BASE_DIR}/sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ]; then
						rm -f ${BASE_DIR}/sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz
					fi
					if [ -d ${BASE_DIR}/sources/git/${PKG_NAME}-${PKG_VERSION}_git ]; then
						rm -rf ${BASE_DIR}/sources/git/${PKG_NAME}-${PKG_VERSION}_git/
					fi
					if [ -d ${BASE_DIR}/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}_git ]; then
						rm -rf ${BASE_DIR}/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}_git
					fi
					echo "克隆：$i 所需源码包到${BASE_DIR}/sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz..."
					echo ${BASE_DIR}/scripts/tools/git_clone.sh "${PKG_NAME}" "${PKG_VERSION}" "${URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}"
					${BASE_DIR}/scripts/tools/git_clone.sh "${PKG_NAME}" "${PKG_VERSION}" "${URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
					if [ "x$?" != "x0" ]; then
						echo "${URL} 克隆失败！"
						echo "克隆 ${URL} 失败！" >> logs/download_fail.log
						((FAIL_COUNT++))
						continue;
					fi
					if [ -f ${BASE_DIR}/sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ]; then
						md5sum ${BASE_DIR}/sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz | awk -F' ' '{print $1}' > ${BASE_DIR}/sources/downloads/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash
						eval FORCE_$(echo ${PKG_NAME}_${PKG_VERSION} | sed -e "s@-@_@g" -e "s@\.@_@g" )_git=1
					else
						echo "sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz 文件未找到，请检查！"
						echo "${i} 步骤中克隆 ${URL} 的打包文件 sources/downloads/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz 未找到！" >> logs/download_fail.log
						((FAIL_COUNT++))
						continue;
					fi
				fi
			fi
			;;
		file:)
			if [ -f ${BASE_DIR}/sources/files/${SAVE_FILENAME} ]; then
				echo "复制：$i 所需源码包到${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME}..."
				cp -a ${BASE_DIR}/sources/files/${URL##*/} ${BASE_DIR}/sources/downloads/files/${SAVE_FILENAME}
			else
				NO_FILE="${NO_FILE}
${i} 没有找到所需的文件${URL##*/}，请检查。"
			fi
			;;
		*)
			echo "$i:		${URL%%/*}"
			;;
		esac
	else
		NO_FILE="${NO_FILE}
${i} 没有下载路径，请检查。"
	fi


	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -name *.url)" != "x" ]; then
		echo "发现${i}存在需要下载的资源文件……"
		for url_i in $(ls ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/*.url)
		do
			RESOURCES_URL="$(cat ${url_i} | grep ^URL= | awk -F'=' '{ print $2 }')"
			RESOURCES_FILENAME="$(cat ${url_i} | grep ^FILENAME= | awk -F'=' '{ print $2 }')"
			RESOURCES_MODE="$(cat ${url_i} | grep ^MODE= | awk -F'=' '{ print $2 }')"
			PKG_GIT_BRANCH=""
			PKG_GIT_COMMIT=""
	        	if [ "x${PROXY_MODE}" == "x1" ]; then
	        	        set_proxy "${RESOURCES_URL}"
		        fi
			case "${RESOURCES_URL%%/*}" in
		                https: | http: | ftps: | ftp: | git:)
					if [ "x${RESOURCES_MODE}" == "xGIT" ]; then
						PKG_GIT_BRANCH="$(cat ${url_i} | grep ^GIT_BRANCH= | awk -F'=' '{ print $2 }')"
						PKG_GIT_COMMIT="$(cat ${url_i} | grep ^GIT_COMMIT= | awk -F'=' '{ print $2 }')"
						if [ "x${FORCE_DOWN}" == "xFALSE" ] && ([ "x${GIT_UPDATE}" == "xFALSE" ] || [ "x${PKG_GIT_COMMIT}" != "x" ]) && [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ] && [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash ]; then
							echo "$i 所需源码包 ${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 已下载。"
						else
							if [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash ]; then
								rm -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash
							fi
							if [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ]; then
								rm -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz
							fi
							if [ -d ${BASE_DIR}/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${RESOURCES_FILENAME}_git/ ]; then
								rm -rf ${BASE_DIR}/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${RESOURCES_FILENAME}_git/
							fi
							echo "克隆：$i 所需资源文件到${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz..."
							mkdir -p ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/{files,hash}/
							echo ${BASE_DIR}/scripts/tools/git_clone.sh -d "${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/" "${PKG_NAME}" "${RESOURCES_FILENAME}" "${RESOURCES_URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}"
							${BASE_DIR}/scripts/tools/git_clone.sh -d "${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/" "${PKG_NAME}" "${RESOURCES_FILENAME}" "${RESOURCES_URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}"
							if [ "x$?" != "x0" ]; then
								echo "${URL} 克隆失败！"
								echo "克隆 ${URL} 失败！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
							if [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ]; then
								md5sum ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz | awk -F' ' '{print $1}' > ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash
							else
								echo "${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 文件未找到，请检查！"
								echo "${i} 步骤中所需资源文件从 ${URL} 克隆的打包文件 ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 未找到！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
						fi
					else
						if [ "x${GIT_ONLY}" == "xFALSE" ]; then
							if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ] && [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash ]; then
        			                                echo "$i 所需资源文件${RESOURCES_FILENAME}已下载。"
	        		                        else
								echo "下载${RESOURCES_FILENAME}: ${RESOURCES_URL}..."
								mkdir -p ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/{files,hash}/
								if [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ]; then
									rm -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}
								fi
								wget -c ${RESOURCES_URL} -O ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}
								if [ "x$?" != "x0" ]; then
									echo "${RESOURCES_URL} 下载失败！"
									echo "下载${i}资源文件 ${RESOURCES_URL} 失败！" >> logs/download_fail.log
									((FAIL_COUNT++))
									continue;
								fi
								md5sum ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} | awk -F' ' '{print $1}' > ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash
							fi
						fi
					fi
					;;
				*)
					echo "${RESOURCES_URL} 地址无法识别，下载失败。"
					((FAIL_COUNT++))
					;;
			esac
		done
		echo "已完成${i}需要下载的资源文件。"
	fi

	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -name *.listfile)" != "x" ]; then
		if [ "x${GIT_ONLY}" == "xFALSE" ]; then
			echo "发现${i}存在需要下载的资源组文件……"
			for listfile_i in $(ls ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/*.listfile)
			do
				LIST_URL="$(cat ${listfile_i} | grep ^URL= | awk -F'=' '{ print $2 }')"
				LIST_FILENAME="$(cat ${listfile_i} | grep ^FILE= | awk -F'=' '{ print $2 }')"
				LIST_NAME="$(basename ${listfile_i})"
				if [ -f ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash ] && [ "x$(md5sum ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash)" ]; then
					echo "$i 所需资源组${LIST_NAME}内的文件都已下载。"
				else
					case "${LIST_URL%%/*}" in
		                                https: | http: | ftps: | ftp:)
							echo "从${LIST_URL}下载${LIST_FILENAME}中的文件..."
							mkdir -p ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/{files,hash}/
							mkdir -p ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir
							wget -c -B ${LIST_URL} -i ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} -P ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/
							if [ "x$?" != "x0" ]; then
								echo "从 ${LIST_URL} 下载资源组文件 ${LIST_FILENAME} 失败！"
								echo "${i}从${LIST_URL}下载资源组文件 ${LIST_FILENAME} 失败！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
							pushd ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/
								tar -czf ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir.tar.gz ${LIST_NAME}_dir
							popd
							md5sum ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}' > ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash
							;;
						*)
							echo "资源组${LIST_FILENAME}中的${LIS_URL} 地址无法识别，下载失败。"
							((FAIL_COUNT++))
							;;
					esac
				fi
			done
			echo "已完成${i}需要下载的资源文件。"
		fi
	fi
done

if [ "x${NO_FILE}" != "x警告：" ]; then
	echo "${NO_FILE}"
fi

if [ "x${FAIL_COUNT}" != "x1" ]; then
	echo "有文件下载失败，请检查失败记录 logs/download_fail.log"
	exit -1
fi
