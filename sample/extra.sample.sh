#!/usr/bin/env bash
## 此文件为自定义脚本模板，你需要复制此文件至 config 目录并更名为 extra.sh，同时启用配置文件中的相关变量后才可以使用

## 你需要填写此脚本的以下几处地方：
## 1. 作者昵称
## 2. 作者脚本地址链接
## 3. 作者脚本名称
## 4. 自定义命令（选填）

## Tips:看清楚板块和其中的注释，不要乱写乱改

##############################  定  义  代  理  相  关  设  置  ##############################
## 根据配置文件中的设置判定是否启用了下载代理，${ProxyJudge}是一个判定变量，建议不要移除，配置文件中如果没用启用该判定变量会赋值为空
[[ ${EnableExtraShellProxy} == true ]] && ProxyJudge=${GithubProxy} || ProxyJudge=""

##############################  作  者  昵  称  &  脚  本  地  址  &  脚  本  名  称  （必填）  ##############################

author_list=""
## 添加更多作者昵称（必填）示例：author_list="testuser1 testuser2"  直接追加进双引号内，不要新定义变量，多个值用空格隔开

scripts_base_url_1=${ProxyJudge}
my_scripts_list_1=""

# 将相应作者的脚本地址到以下变量 scripts_base_url 中，注意带上项目分支名称，如果脚本在文件夹中也要带上文件夹名，不要忘了最后面的斜杠，并且一定要使用 raw 地址，Gitee 地址需去除下载判定变量
# 将相应作者的脚本填写到以下变量 my_scripts_list 中，多个值用空格隔开

## 示例：scripts_base_url_2=${ProxyJudge}https://raw.githubusercontent.com/testuser/testrepository/main/
##       my_scripts_list_2="jd_test1.js jd_test2.js jd_test3.js"

## 如果拉取的脚本在对应仓库的某个文件夹下注意先创建对应目录
## Make_Dir "$ScriptsDir/<文件夹名>"

##############################  主 命 令  ##############################
## 以下为脚本核心内容，不懂不要随意更改
cd $RootDir

## 随机函数
rand() {
  min=$1
  max=$(($2 - $min + 1))
  num=$(cat /proc/sys/kernel/random/uuid | cksum | awk -F ' ' '{print $1}')
  echo $(($num % $max + $min))
}
index=1
for author in $author_list; do
  # 下载my_scripts_list中的每个js文件，重命名增加前缀"作者昵称_"，增加后缀".new"
  eval scripts_list=\$my_scripts_list_${index}
  #echo $scripts_list
  eval url_list=\$scripts_base_url_${index}
  #echo $url_list

  ## 判断脚本来源仓库
  format_url=$(echo $url_list | awk -F '.com' '{print$NF}' | sed 's/.$//')
  if [[ $(echo $url_list | grep -Eo "github|gitee") == "github" ]]; then
    repository_platform="https://github.com"
    repository_branch=$(echo $format_url | awk -F '/' '{print$4}')
    reformat_url=$(echo $format_url | sed "s|$repository_branch|tree/$repository_branch|g")
    [[ ${EnableExtraShellProxy} == true ]] && DownloadJudge="(代理)" || DownloadJudge=""
  elif [[ $(echo $url_list | grep -Eo "github|gitee") == "gitee" ]]; then
    repository_platform="https://gitee.com"
    reformat_url=$(echo $format_url | sed "s|/raw/|/tree/|g")
    DownloadJudge=""
  fi
  repository_url="$repository_platform$reformat_url"
  echo -e "[${YELLOW}更新${PLAIN}] ${!author} ${DownloadJudge}"
  echo -e "[${YELLOW}仓库${PLAIN}] $repository_url"

  for js in $scripts_list; do
    eval url=$url_list$js
    echo $url
    eval name=$js
    wget -q --no-check-certificate $url -O scripts/$name.new -T 10

    # 如果上一步下载没问题，才去掉后缀".new"，如果上一步下载有问题，就保留之前正常下载的版本
    # 随机添加个cron到crontab.list
    if [ $? -eq 0 ]; then
      mv -f scripts/$name.new scripts/$name
      echo -e "$COMPLETE $name"

      ## 不导入某脚本的定时
      ## [[ $name == "jd_test.js" ]] && continue

      croname=$(echo "$name" | awk -F\. '{print $1}' | perl -pe "{s|^jd_||; s|^jx_||; s|^jr_||;}")
      script_cron_standard=$(cat $ScriptsDir/$name | grep "https" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5}' | sort -u | head -n 1)
      if [[ -z ${script_cron_standard} ]]; then
        tmp1=$(grep -E "cron|script-path|tag|\* \*|$name" $ScriptsDir/$name | grep -Ev "^http.*:" | head -1 | perl -pe '{s|[a-zA-Z\"\.\=\:\:\_]||g;}')
        ## 判断开头
        tmp2=$(echo "${tmp1}" | awk -F '[0-9]' '{print$1}' | sed 's/\*/\\*/g; s/\./\\./g')
        ## 判断表达式的第一个数字（分钟）
        tmp3=$(echo "${tmp1}" | grep -Eo "[0-9]" | head -1)
        ## 判定开头是否为空值
        if [[ $(echo "${tmp2}" | perl -pe '{s| ||g;}') = "" ]]; then
          script_cron=$(echo "${tmp1}" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5; else if ($1~/^[*]/) print $2,$3,$4,$5,$6}')
        else
          script_cron=$(echo "${tmp1}" | perl -pe "{s|${tmp2}${tmp3}|${tmp3}|g;}" | awk '{if($1~/^[0-9]{1,2}/) print $1,$2,$3,$4,$5; else if ($1~/^[*]/) print $2,$3,$4,$5,$6}')
        fi
      else
        script_cron=${script_cron_standard}
      fi
      if [ -z "${script_cron}" ]; then
        cron_min=$(rand 1 59)
        cron_hour=$(rand 1 23)
        [ $(grep -c " $TaskCmd $croname" $ListCrontabUser) -eq 0 ] && sed -i "/hang up/a${cron_min} ${cron_hour} * * * $TaskCmd $croname" $ListCrontabUser
      else
        [ $(grep -c " $TaskCmd $croname" $ListCrontabUser) -eq 0 ] && sed -i "/hang up/a${script_cron} $TaskCmd $croname" $ListCrontabUser
      fi
    else
      [ -f scripts/$name.new ] && rm -f scripts/$name.new
      echo -e "[${RED}FAIL${PLAIN}] $name 更新失败"
    fi
  done
  let index+=1
  echo ''
done
##############################  自  定  义  命  令  （选填）  ##############################

## 删除脚本和定时
DeletedScripts="" # 完整脚本名称填入双引号内，多个用空格隔开
for del in ${DeletedScripts}; do
  [ -f $ScriptsDir/$del ] && rm -rf $ScriptsDir/$del && sed -i "/ $TaskCmd $(echo "$del" | awk -F\. '{print $1}' | perl -pe "{s|^jd_||; s|^jx_||; s|^jr_||;}")/d" $ListCrontabUser
done
