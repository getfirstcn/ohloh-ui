  xml.item do
    xml.title posts.topic.title
    xml.description markdown_format(posts.body.to_s)
    xml.pubDate posts.created_at.rfc822
    xml.guid [request.host_with_port, posts.topic_id.to_s, posts.id.to_s].join(":"), "isPermaLink" => "false"
    xml.author posts.account.login
    xml.link "http://#{request.host_with_port}#{topic_path(posts.topic, anchor: "post_#{posts.id}")}"
  end