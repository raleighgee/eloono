class LoadSysIgnoreWords < ActiveRecord::Migration
  def up
    Sysign.create(:word=>"the")
    Sysigword.create(:word=>"to")
    Sysigword.create(:word=>"a")
    Sysigword.create(:word=>"of")
    Sysigword.create(:word=>"")
    Sysigword.create(:word=>"rt")
    Sysigword.create(:word=>"and")
    Sysigword.create(:word=>"in")
    Sysigword.create(:word=>"for")
    Sysigword.create(:word=>"is")
    Sysigword.create(:word=>"you")
    Sysigword.create(:word=>"on")
    Sysigword.create(:word=>"via")
    Sysigword.create(:word=>"your")
    Sysigword.create(:word=>"i")
    Sysigword.create(:word=>"by")
    Sysigword.create(:word=>"with")
    Sysigword.create(:word=>"it")
    Sysigword.create(:word=>"at")
    Sysigword.create(:word=>"this")
    Sysigword.create(:word=>"that")
    Sysigword.create(:word=>"from")
    Sysigword.create(:word=>"are")
    Sysigword.create(:word=>"how")
    Sysigword.create(:word=>"my")
    Sysigword.create(:word=>"be")
    Sysigword.create(:word=>"what")
    Sysigword.create(:word=>"have")
    Sysigword.create(:word=>"not")
    Sysigword.create(:word=>"we")
    Sysigword.create(:word=>"about")
    Sysigword.create(:word=>"an")
    Sysigword.create(:word=>"its")
    Sysigword.create(:word=>"can")
    Sysigword.create(:word=>"if")
    Sysigword.create(:word=>"just")
    Sysigword.create(:word=>"more")
    Sysigword.create(:word=>"do")
    Sysigword.create(:word=>"our")
    Sysigword.create(:word=>"all")
    Sysigword.create(:word=>"as")
    Sysigword.create(:word=>"will")
    Sysigword.create(:word=>"get")
    Sysigword.create(:word=>"up")
    Sysigword.create(:word=>"like")
    Sysigword.create(:word=>"or")
    Sysigword.create(:word=>"so")
    Sysigword.create(:word=>"but")
    Sysigword.create(:word=>"why")
    Sysigword.create(:word=>"when")
    Sysigword.create(:word=>"dont")
    Sysigword.create(:word=>"who")
    Sysigword.create(:word=>"has")
    Sysigword.create(:word=>"they")
    Sysigword.create(:word=>"was")
    Sysigword.create(:word=>"im")
    Sysigword.create(:word=>"than")
    Sysigword.create(:word=>"2012")
    Sysigword.create(:word=>"2013")
    Sysigword.create(:word=>"there")
    Sysigword.create(:word=>"here")
    Sysigword.create(:word=>"his")
    Sysigword.create(:word=>"10")
    Sysigword.create(:word=>"5")
    Sysigword.create(:word=>"them")
    Sysigword.create(:word=>"w")
    Sysigword.create(:word=>"youre")
    Sysigword.create(:word=>"2")
    Sysigword.create(:word=>"ff")
    Sysigword.create(:word=>"cc")
    Sysigword.create(:word=>"where")
    Sysigword.create(:word=>"did")
    Sysigword.create(:word=>"which")
    Sysigword.create(:word=>"thx")
    Sysigword.create(:word=>"1")
  end

  def down
  end
end
