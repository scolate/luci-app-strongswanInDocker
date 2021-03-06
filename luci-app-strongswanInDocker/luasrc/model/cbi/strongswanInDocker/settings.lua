local s = require "luci.sys"
local net = require"luci.model.network".init()
local ifaces = s.net:devices()
local m, s, o
mp = Map("strongswanInDocker", translate("IPSec VPN Server(Docker)"))
mp.description = translate("IPSec VPN connectivity using the native built-in VPN Client on iOS or Andriod (IKEv1 with PSK and Xauth) & Windows 10 (IKEv2)")
mp.template = "strongswanInDocker/index"

s = mp:section(TypedSection, "service")
s.anonymous = true

o = s:option(DummyValue, "strongswanInDocker_status", translate("Current Condition"))
o.default = "正在检测..."
o.template = "strongswanInDocker/status"

enabled = s:option(Flag, "enabled", translate("Enable"))
enabled.default = 0
enabled.rmempty = false

useLanDHCP = s:option(Flag, "useLanDHCP", translate("useLanDHCP"))
useLanDHCP.default = 1
useLanDHCP.rmempty = false

clientip = s:option(Value, "clientip", translate("VPN Client IP"))
clientip.datatype = "ip4addr"
clientip.description = translate("VPN Client reserved started IP addresses with the same subnet mask")
clientip.optional = false
clientip.rmempty = false

lanDHCPServer = s:option(Value, "lanDHCPServer", translate("lanDHCPServer"))
lanDHCPServer.datatype = "ip4addr"
lanDHCPServer.optional = false
lanDHCPServer.rmempty = false

--[[
]]--

clientdns = s:option(Value, "clientdns", translate("VPN Client DNS"))
clientdns.datatype = "ip4addr"
clientdns.description = translate("DNS using in VPN tunnel.")
clientdns.optional = false
clientdns.rmempty = false

secret = s:option(Value, "secret", translate("Secret Pre-Shared Key"))
secret.password = true

ikev2enabled = s:option(Flag, "ikev2enabled", translate("ikev2enabled"),
		      translate("请在启用前，将路由DDNS域名证书(PEM格式)按路径放好。<br>" ..
						"CA及中间证书保存到/etc/strongswanInDocker/ipsec.d/cacerts中，<br>" ..
			            "域名证书保存到/etc/strongswanInDocker/ipsec.d/certs并且命名为SERVER.crt，<br>" ..
						"域名证书私钥保存到/etc/strongswanInDocker/ipsec.d/private并且命名为KEY.key。"))
ikev2enabled.default = 0
ikev2enabled.rmempty = false

routerDomain = s:option(Value, "routerDomain", translate("routerDomain"),
		      translate("请输入路由DDNS域名，需要和证书中域名一致，不支持通配符证书。"))
routerDomain.rmempty = false

function mp.on_save(self)
    require "luci.model.uci"
    require "luci.sys"

    local have_ike_rule = false
    local have_ipsec_rule = false
    local have_ah_rule = false
    local have_esp_rule = false

    luci.model.uci.cursor():foreach('firewall', 'rule', function(section)
        if section.name == 'ike' then have_ike_rule = true end
        if section.name == 'ipsec' then have_ipsec_rule = true end
        if section.name == 'ah' then have_ah_rule = true end
        if section.name == 'esp' then have_esp_rule = true end
    end)

    if not have_ike_rule then
        local cursor = luci.model.uci.cursor()
        local ike_rulename = cursor:add('firewall', 'rule')
        cursor:tset('firewall', ike_rulename, {
            ['name'] = 'ike',
            ['target'] = 'ACCEPT',
            ['src'] = 'wan',
            ['proto'] = 'udp',
            ['dest_port'] = 500
        })
        cursor:save('firewall')
        cursor:commit('firewall')
    end
    if not have_ipsec_rule then
        local cursor = luci.model.uci.cursor()
        local ipsec_rulename = cursor:add('firewall', 'rule')
        cursor:tset('firewall', ipsec_rulename, {
            ['name'] = 'ipsec',
            ['target'] = 'ACCEPT',
            ['src'] = 'wan',
            ['proto'] = 'udp',
            ['dest_port'] = 4500
        })
        cursor:save('firewall')
        cursor:commit('firewall')
    end
    if not have_ah_rule then
        local cursor = luci.model.uci.cursor()
        local ah_rulename = cursor:add('firewall', 'rule')
        cursor:tset('firewall', ah_rulename, {
            ['name'] = 'ah',
            ['target'] = 'ACCEPT',
            ['src'] = 'wan',
            ['proto'] = 'ah'
        })
        cursor:save('firewall')
        cursor:commit('firewall')
    end
    if not have_esp_rule then
        local cursor = luci.model.uci.cursor()
        local esp_rulename = cursor:add('firewall', 'rule')
        cursor:tset('firewall', esp_rulename, {
            ['name'] = 'esp',
            ['target'] = 'ACCEPT',
            ['src'] = 'wan',
            ['proto'] = 'esp'
        })
        cursor:save('firewall')
        cursor:commit('firewall')
    end

end

mp:append(Template("strongswanInDocker/setup"))
mp:append(Template("strongswanInDocker/download"))
return mp
